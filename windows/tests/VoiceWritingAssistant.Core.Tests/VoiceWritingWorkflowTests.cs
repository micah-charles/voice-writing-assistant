using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class VoiceWritingWorkflowTests
{
    [Fact]
    public async Task RunsRecordingToDeliveryAgainstOriginalTarget()
    {
        var events = new List<string>();
        var target = new CapturedContext { ExecutableName = "slack.exe", PlatformTargetId = "ABCD" };
        var audio = new FakeAudio(events);
        var delivery = new FakeDelivery(events);
        var profiles = new ProfileCatalog([
            new AppProfile
            {
                Id = "chat",
                Match = new AppProfileMatch { ExecutableNames = ["slack.exe"] },
                Mode = AppMode.Chat,
                Style = ProcessingStyle.Conversational,
                AutoPaste = true,
                AutoSend = false
            }
        ]);
        await using var workflow = new VoiceWritingWorkflow(
            audio,
            new FakeSpeech(events),
            new FakeContext(target, events),
            delivery,
            new ProcessorRouter([new FakeProcessor(events)], new RuleBasedProcessor()),
            profiles,
            new AppSettings());

        await workflow.StartAsync(CancellationToken.None);
        await workflow.StopAsync(CancellationToken.None);

        Assert.Equal(WorkflowStage.Completed, workflow.Status.Stage);
        Assert.Equal(["context", "audio-start", "audio-stop", "stt", "process-chat-conversational", "deliver"], events);
        Assert.Equal(target, delivery.Target);
        Assert.True(delivery.AutoPaste);
        Assert.False(delivery.AutoSend);
    }

    [Fact]
    public async Task ReviewModeStoresHistoryAndWaitsForExplicitPaste()
    {
        var events = new List<string>();
        var history = new FakeHistoryStore();
        var dictionary = new FakeDictionaryStore([
            new PersonalDictionaryEntry { Term = "open ai", PreferredForm = "OpenAI", Aliases = ["open ai"] }
        ]);
        var delivery = new FakeDelivery(events);
        await using var workflow = new VoiceWritingWorkflow(
            new FakeAudio(events), new FakeSpeech(events, "open ai is useful"),
            new FakeContext(new CapturedContext { ActiveApplicationName = "Notepad", PlatformTargetId = "1" }, events),
            delivery, new ProcessorRouter([new EchoProcessor()], new RuleBasedProcessor()),
            new ProfileCatalog([]), new AppSettings { ReviewBeforePaste = true, StoreHistory = true }, history, dictionary);

        await workflow.StartAsync();
        await workflow.StopAsync();

        Assert.Equal(WorkflowStage.AwaitingReview, workflow.Status.Stage);
        Assert.DoesNotContain("deliver", events);
        Assert.Single(history.Entries);
        Assert.Contains("OpenAI", history.Entries[0].ProcessedText);

        await workflow.PasteReviewedAsync();
        Assert.Equal(WorkflowStage.Completed, workflow.Status.Stage);
        Assert.Contains("deliver", events);
    }

    [Fact]
    public async Task SelectedTextWorkflowUsesTransformMode()
    {
        var events = new List<string>();
        var processor = new CapturingProcessor();
        await using var workflow = new VoiceWritingWorkflow(
            new FakeAudio(events), new FakeSpeech(events, "make this concise"),
            new FakeContext(new CapturedContext { SelectedText = "This is rather long.", PlatformTargetId = "1" }, events),
            new FakeDelivery(events), new ProcessorRouter([processor], new RuleBasedProcessor()),
            new ProfileCatalog([]), new AppSettings());

        await workflow.StartSelectedTextTransformAsync();
        await workflow.StopAsync();

        Assert.Equal(AppMode.SelectedTextTransform, processor.Request?.Mode);
        Assert.Equal("This is rather long.", processor.Request?.Context.SelectedText);
    }

    [Fact]
    public async Task ReplacingLastPasteUndoesThenDeliversAlternative()
    {
        var events = new List<string>();
        var delivery = new FakeDelivery(events);
        await using var workflow = new VoiceWritingWorkflow(
            new FakeAudio(events), new FakeSpeech(events),
            new FakeContext(new CapturedContext { PlatformTargetId = "1" }, events),
            delivery, new ProcessorRouter([new EchoProcessor()], new RuleBasedProcessor()),
            new ProfileCatalog([]), new AppSettings());

        await workflow.StartAsync();
        await workflow.StopAsync();
        await workflow.ReplaceLastPasteAsync(new ProcessingResult("Alternative result.", "Alternate", TimeSpan.Zero));

        Assert.Equal(["hello there", "Alternative result."], delivery.DeliveredTexts);
        Assert.Equal(["undo", "deliver"], events.TakeLast(2));
    }

    [Fact]
    public async Task SilenceTranscriptFailsClearlyWithoutPasting()
    {
        var events = new List<string>();
        await using var workflow = new VoiceWritingWorkflow(
            new FakeAudio(events), new FakeSpeech(events, "[silence]"),
            new FakeContext(new CapturedContext { PlatformTargetId = "1" }, events),
            new FakeDelivery(events), new ProcessorRouter([new EchoProcessor()], new RuleBasedProcessor()),
            new ProfileCatalog([]), new AppSettings());

        await workflow.StartAsync();
        await workflow.StopAsync();

        Assert.Equal(WorkflowStage.Failed, workflow.Status.Stage);
        Assert.Contains("No speech was detected", workflow.Status.Message);
        Assert.DoesNotContain("deliver", events);
    }

    private sealed class FakeAudio(List<string> events) : IAudioCaptureService
    {
        public Task StartAsync(CancellationToken cancellationToken) { events.Add("audio-start"); return Task.CompletedTask; }
        public Task<string> StopAsync(CancellationToken cancellationToken) { events.Add("audio-stop"); return Task.FromResult("audio.wav"); }
        public Task CancelAsync() => Task.CompletedTask;
        public ValueTask DisposeAsync() => ValueTask.CompletedTask;
    }

    private sealed class FakeSpeech(List<string> events, string text = "hello there") : ISpeechToTextService
    {
        public Task<string> TranscribeAsync(string audioPath, IReadOnlyList<string> hints, CancellationToken cancellationToken)
        {
            events.Add("stt");
            return Task.FromResult(text);
        }
    }

    private sealed class FakeContext(CapturedContext target, List<string> events) : IContextCaptureService
    {
        public Task<CapturedContext> CaptureAsync(CancellationToken cancellationToken)
        {
            events.Add("context");
            return Task.FromResult(target);
        }
    }

    private sealed class FakeProcessor(List<string> events) : ITextProcessor
    {
        public string Name => "Fake";
        public Task<ProcessingResult> ProcessAsync(ProcessingRequest request, CancellationToken cancellationToken)
        {
            events.Add($"process-{request.Mode.ToString().ToLowerInvariant()}-{request.Style.ToString().ToLowerInvariant()}");
            return Task.FromResult(new ProcessingResult("Hello there.", Name, TimeSpan.Zero));
        }
    }

    private sealed class FakeDelivery(List<string> events) : ITextDeliveryService
    {
        public CapturedContext? Target { get; private set; }
        public bool AutoPaste { get; private set; }
        public bool AutoSend { get; private set; }
        public List<string> DeliveredTexts { get; } = [];

        public Task DeliverAsync(string text, CapturedContext target, bool autoPaste, bool restoreClipboard, bool autoSend, CancellationToken cancellationToken)
        {
            events.Add("deliver");
            Target = target;
            AutoPaste = autoPaste;
            AutoSend = autoSend;
            DeliveredTexts.Add(text);
            return Task.CompletedTask;
        }
        public Task UndoLastAsync(CapturedContext target, CancellationToken cancellationToken) { events.Add("undo"); return Task.CompletedTask; }
    }

    private sealed class EchoProcessor : ITextProcessor
    {
        public string Name => "Echo";
        public Task<ProcessingResult> ProcessAsync(ProcessingRequest request, CancellationToken cancellationToken) =>
            Task.FromResult(new ProcessingResult(request.RawText, Name, TimeSpan.Zero));
    }

    private sealed class CapturingProcessor : ITextProcessor
    {
        public string Name => "Capture";
        public ProcessingRequest? Request { get; private set; }
        public Task<ProcessingResult> ProcessAsync(ProcessingRequest request, CancellationToken cancellationToken)
        {
            Request = request;
            return Task.FromResult(new ProcessingResult(request.Context.SelectedText ?? request.RawText, Name, TimeSpan.Zero));
        }
    }

    private sealed class FakeHistoryStore : IHistoryStore
    {
        public List<HistoryEntry> Entries { get; } = [];
        public Task AppendAsync(HistoryEntry entry, CancellationToken cancellationToken = default) { Entries.Add(entry); return Task.CompletedTask; }
        public Task UpdateAlternativesAsync(Guid id, IReadOnlyList<ProcessingResult> alternatives, CancellationToken cancellationToken = default) => Task.CompletedTask;
    }

    private sealed class FakeDictionaryStore(IReadOnlyList<PersonalDictionaryEntry> entries) : IDictionaryStore
    {
        public Task<IReadOnlyList<PersonalDictionaryEntry>> LoadAsync(CancellationToken cancellationToken = default) => Task.FromResult(entries);
    }
}
