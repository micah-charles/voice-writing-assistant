namespace VoiceWritingAssistant.Core;

public sealed class VoiceWritingWorkflow(
    IAudioCaptureService audio,
    ISpeechToTextService speechToText,
    IContextCaptureService contextCapture,
    ITextDeliveryService delivery,
    ProcessorRouter processors,
    ProfileCatalog profiles,
    AppSettings settings,
    IHistoryStore? historyStore = null,
    IDictionaryStore? dictionaryStore = null,
    IAudioRecordingStore? audioRecordingStore = null) : IAsyncDisposable
{
    private readonly SemaphoreSlim _gate = new(1, 1);
    private readonly TerminologyService _terminology = new();
    private readonly ChineseConversionService _chineseConversion = new();
    private CapturedContext? _target;
    private CancellationTokenSource? _pipelineCancellation;
    private string? _pendingRawText;
    private ProcessingResult? _pendingResult;
    private AppProfile? _pendingProfile;
    private bool _selectedTextTransform;

    public WorkflowStatus Status { get; private set; } = new(WorkflowStage.Idle, "Ready — hold Control+R to dictate");
    public IReadOnlyList<ProcessingResult> AlternativeResults { get; private set; } = [];
    public event EventHandler<WorkflowStatus>? StatusChanged;
    public event EventHandler<IReadOnlyList<ProcessingResult>>? AlternativeResultsChanged;

    public Task StartAsync(CancellationToken cancellationToken = default) => StartInternalAsync(false, cancellationToken);

    public Task StartSelectedTextTransformAsync(CancellationToken cancellationToken = default) => StartInternalAsync(true, cancellationToken);

    private async Task StartInternalAsync(bool selectedTextTransform, CancellationToken cancellationToken)
    {
        if (Status.Stage is not (WorkflowStage.Idle or WorkflowStage.Completed or WorkflowStage.Failed)) return;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (Status.Stage is not (WorkflowStage.Idle or WorkflowStage.Completed or WorkflowStage.Failed)) return;
            _pipelineCancellation?.Cancel();
            _pipelineCancellation?.Dispose();
            _pipelineCancellation = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            _pendingRawText = null; _pendingResult = null; _pendingProfile = null;
            AlternativeResults = [];
            AlternativeResultsChanged?.Invoke(this, AlternativeResults);
            SetStatus(WorkflowStage.Starting, "Preparing microphone…");
            _target = await contextCapture.CaptureAsync(_pipelineCancellation.Token).ConfigureAwait(false);
            _selectedTextTransform = selectedTextTransform;
            if (selectedTextTransform && string.IsNullOrWhiteSpace(_target.SelectedText))
            {
                SetStatus(WorkflowStage.Failed, "Select text first, then hold Control+Alt+E.");
                return;
            }
            await audio.StartAsync(_pipelineCancellation.Token).ConfigureAwait(false);
            SetStatus(WorkflowStage.Recording, selectedTextTransform ? "Speak the transformation instruction — release E to finish" : "Listening — release Control+R to finish");
        }
        catch (Exception exception) when (exception is not OperationCanceledException) { SetStatus(WorkflowStage.Failed, exception.Message); }
        finally { _gate.Release(); }
    }

    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        if (Status.Stage != WorkflowStage.Recording) return;
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (Status.Stage != WorkflowStage.Recording || _target is null) return;
            using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken, _pipelineCancellation?.Token ?? CancellationToken.None);
            SetStatus(WorkflowStage.Transcribing, "Transcribing locally…");
            var audioPath = await audio.StopAsync(linked.Token).ConfigureAwait(false);
            string? archivedAudioPath = null;
            if (settings.StoreAudioRecordings && audioRecordingStore is not null)
            {
                try { archivedAudioPath = await audioRecordingStore.ArchiveAsync(audioPath, DateTimeOffset.Now, linked.Token).ConfigureAwait(false); }
                catch { /* Audio archiving must never prevent transcription. */ }
            }
            IReadOnlyList<PersonalDictionaryEntry> dictionary = dictionaryStore is null
                ? []
                : await dictionaryStore.LoadAsync(linked.Token).ConfigureAwait(false);
            var hints = _terminology.BuildHints(dictionary);
            var transcript = (await speechToText.TranscribeAsync(audioPath, hints, linked.Token).ConfigureAwait(false)).Trim();
            var transcriptionMetadata = (speechToText as IAvailableSpeechToTextService)?.LastMetadata;
            if (transcriptionMetadata is not null)
                SetStatus(WorkflowStage.CapturingContext, $"Transcribed with {transcriptionMetadata.Provider}{(transcriptionMetadata.FallbackUsed ? " (Whisper fallback)" : "")}", rawTranscript: transcript);
            if (transcript.Length == 0 || IsSilenceTranscript(transcript))
                throw new InvalidOperationException("No speech was detected. Check the microphone input and speak while holding R.");
            transcript = _terminology.Normalize(transcript, dictionary);
            SetStatus(WorkflowStage.CapturingContext, "Applying application profile…", rawTranscript: transcript);
            var profile = _selectedTextTransform ? null : profiles.Resolve(_target);
            var mode = _selectedTextTransform ? AppMode.SelectedTextTransform : profile?.Mode ?? AppMode.General;
            var style = profile?.Style ?? settings.ProcessingStyle;
            var outputLanguage = profile?.OutputLanguage ?? settings.OutputLanguage;

            SetStatus(WorkflowStage.Processing, "Cleaning the transcript…", rawTranscript: transcript);
            var request = new ProcessingRequest(transcript, _target, mode, style, outputLanguage);
            var processed = await processors.ProcessAsync(request, linked.Token).ConfigureAwait(false);
            SetStatus(WorkflowStage.Normalizing, "Normalizing language…", processed.Text, transcript, processed.Provider, processed.Latency);
            var normalized = _terminology.Normalize(processed.Text, dictionary);
            var result = processed with { Text = _chineseConversion.Convert(normalized, settings.OpenCcProfile) };

            Guid? historyId = null;
            if (settings.StoreHistory && historyStore is not null)
            {
                historyId = Guid.NewGuid();
                await historyStore.AppendAsync(new HistoryEntry
                {
                    Id = historyId.Value,
                    RawTranscript = transcript,
                    ProcessedText = result.Text,
                    Provider = result.Provider,
                    Mode = mode,
                    ActiveApplication = _target.ActiveApplicationName,
                    Latency = result.Latency,
                    AudioPath = archivedAudioPath,
                    Transcription = transcriptionMetadata
                }, linked.Token).ConfigureAwait(false);
            }
            _ = CaptureAlternativesAsync(historyId, request, result, dictionary);

            _pendingRawText = transcript; _pendingResult = result; _pendingProfile = profile;
            if (settings.ReviewBeforePaste)
            {
                SetStatus(WorkflowStage.AwaitingReview, "Review result before pasting", result.Text, transcript, result.Provider, result.Latency);
                return;
            }
            await DeliverPendingAsync(result.Text, result.Provider, linked.Token).ConfigureAwait(false);
        }
        catch (OperationCanceledException) { SetStatus(WorkflowStage.Idle, "Cancelled"); }
        catch (Exception exception) { SetStatus(WorkflowStage.Failed, exception.Message); }
        finally { _gate.Release(); }
    }

    public async Task CancelAsync()
    {
        _pipelineCancellation?.Cancel();
        await audio.CancelAsync().ConfigureAwait(false);
        _pendingRawText = null; _pendingResult = null; _pendingProfile = null;
        SetStatus(WorkflowStage.Idle, "Cancelled");
    }

    public Task PasteReviewedAsync(CancellationToken cancellationToken = default) =>
        _pendingResult is null ? Task.CompletedTask : DeliverPendingAsync(_pendingResult.Text, _pendingResult.Provider, cancellationToken);

    public Task UseRawAsync(CancellationToken cancellationToken = default) =>
        string.IsNullOrWhiteSpace(_pendingRawText) ? Task.CompletedTask : DeliverPendingAsync(_pendingRawText, "Raw transcript", cancellationToken);

    public async Task ReplaceLastPasteAsync(ProcessingResult result, CancellationToken cancellationToken = default)
    {
        if (_target is null || string.IsNullOrWhiteSpace(result.Text)) return;
        await delivery.UndoLastAsync(_target, cancellationToken).ConfigureAwait(false);
        _pendingResult = result;
        await DeliverPendingAsync(result.Text, result.Provider, cancellationToken).ConfigureAwait(false);
    }

    private async Task DeliverPendingAsync(string text, string provider, CancellationToken cancellationToken)
    {
        if (_target is null) return;
        SetStatus(WorkflowStage.Pasting, "Delivering text…", text, _pendingRawText, provider, _pendingResult?.Latency);
        var autoPaste = _pendingProfile?.AutoPaste ?? settings.AutoPaste;
        await delivery.DeliverAsync(text, _target, autoPaste, settings.RestoreClipboard, _pendingProfile?.AutoSend ?? false, cancellationToken).ConfigureAwait(false);
        SetStatus(WorkflowStage.Completed, $"{(autoPaste ? "Pasted" : "Copied")} with {provider}", text, _pendingRawText, provider, _pendingResult?.Latency);
    }

    private async Task CaptureAlternativesAsync(
        Guid? historyId,
        ProcessingRequest request,
        ProcessingResult selected,
        IReadOnlyList<PersonalDictionaryEntry> dictionary)
    {
        try
        {
            var alternatives = await processors.GetAlternativesAsync(request, selected.Provider, CancellationToken.None).ConfigureAwait(false);
            var normalized = alternatives
                .Select(result => result with { Text = _chineseConversion.Convert(_terminology.Normalize(result.Text, dictionary), settings.OpenCcProfile) })
                .Where(result => !result.Text.Equals(selected.Text, StringComparison.Ordinal))
                .ToArray();
            if (normalized.Length > 0)
            {
                if (historyId.HasValue && historyStore is not null)
                    await historyStore.UpdateAlternativesAsync(historyId.Value, normalized).ConfigureAwait(false);
                AlternativeResults = normalized;
                AlternativeResultsChanged?.Invoke(this, AlternativeResults);
            }
        }
        catch { }
    }

    private void SetStatus(WorkflowStage stage, string message, string? text = null, string? rawTranscript = null, string? provider = null, TimeSpan? latency = null)
    {
        Status = new WorkflowStatus(stage, message, text, rawTranscript, provider, latency);
        StatusChanged?.Invoke(this, Status);
    }

    private static bool IsSilenceTranscript(string transcript) =>
        transcript.Equals("[silence]", StringComparison.OrdinalIgnoreCase) ||
        transcript.Equals("[blank_audio]", StringComparison.OrdinalIgnoreCase) ||
        transcript.Equals("(silence)", StringComparison.OrdinalIgnoreCase);

    public async ValueTask DisposeAsync()
    {
        _pipelineCancellation?.Cancel(); _pipelineCancellation?.Dispose(); _gate.Dispose();
        await audio.DisposeAsync().ConfigureAwait(false);
    }
}
