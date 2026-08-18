using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

/// <summary>Deterministic local provider selection. Automatic prefers Sherpa for Chinese when installed.</summary>
public sealed class SpeechToTextRouter(
    SpeechToTextProvider provider,
    RecognitionLanguage language,
    IAvailableSpeechToTextService sherpa,
    IAvailableSpeechToTextService whisper) : IAvailableSpeechToTextService
{
    public bool IsAvailable => SelectPrimary().IsAvailable;
    public TranscriptionMetadata? LastMetadata { get; private set; }
    public Task WarmAsync(CancellationToken cancellationToken = default)
    {
        var selected = SelectPrimary();
        return selected.WarmAsync(cancellationToken);
    }

    public async Task<string> TranscribeAsync(string audioPath, IReadOnlyList<string> hints, CancellationToken cancellationToken)
    {
        var primary = SelectPrimary();
        try
        {
            var text = await primary.TranscribeAsync(audioPath, hints, cancellationToken).ConfigureAwait(false);
            LastMetadata = primary.LastMetadata;
            return text;
        }
        catch (OperationCanceledException) { throw; }
        catch when (!ReferenceEquals(primary, whisper))
        {
            // Technical Sherpa/model/VAD failures are safe to fall back to the
            // already-configured Whisper path; the UI still remains local-only.
            var text = await whisper.TranscribeAsync(audioPath, hints, cancellationToken).ConfigureAwait(false);
            LastMetadata = whisper.LastMetadata is { } metadata
                ? metadata with { FallbackUsed = true, FallbackReason = $"{primary.GetType().Name} technical failure" }
                : null;
            return text;
        }
    }

    private IAvailableSpeechToTextService SelectPrimary()
    {
        if (provider == SpeechToTextProvider.WhisperCpp) return whisper;
        if (provider == SpeechToTextProvider.SherpaOnnx) return sherpa.IsAvailable ? sherpa : whisper;
        var chinese = language is RecognitionLanguage.Cantonese or RecognitionLanguage.TraditionalChinese or RecognitionLanguage.MixedChineseEnglish;
        return chinese && sherpa.IsAvailable ? sherpa : whisper;
    }
}
