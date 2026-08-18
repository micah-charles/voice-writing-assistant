using VoiceWritingAssistant.Core;
using VoiceWritingAssistant.Windows.Infrastructure;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class SpeechToTextRouterTests
{
    [Fact]
    public async Task AutomaticCantoneseUsesSherpaFirst()
    {
        var sherpa = new Fake(true, "廣東話");
        var whisper = new Fake(true, "english");
        var router = new SpeechToTextRouter(SpeechToTextProvider.Automatic, RecognitionLanguage.Cantonese, sherpa, whisper);
        var result = await router.TranscribeAsync("x.wav", [], CancellationToken.None);
        Assert.Equal("廣東話", result); Assert.Equal(1, sherpa.Calls); Assert.Equal(0, whisper.Calls);
    }

    [Fact]
    public async Task MissingSherpaFallsBackToWhisper()
    {
        var sherpa = new Fake(false, "never");
        var whisper = new Fake(true, "fallback");
        var router = new SpeechToTextRouter(SpeechToTextProvider.Automatic, RecognitionLanguage.Cantonese, sherpa, whisper);
        Assert.Equal("fallback", await router.TranscribeAsync("x.wav", [], CancellationToken.None)); Assert.Equal(1, whisper.Calls);
    }

    [Fact]
    public async Task SherpaTechnicalFailureFallsBackWithoutSecondNormalDecode()
    {
        var sherpa = new Fake(true, "", new InvalidOperationException("native unavailable"));
        var whisper = new Fake(true, "safe fallback");
        var router = new SpeechToTextRouter(SpeechToTextProvider.Automatic, RecognitionLanguage.Cantonese, sherpa, whisper);
        Assert.Equal("safe fallback", await router.TranscribeAsync("x.wav", [], CancellationToken.None)); Assert.Equal(1, sherpa.Calls); Assert.Equal(1, whisper.Calls);
    }

    private sealed class Fake(bool available, string text, Exception? failure = null) : IAvailableSpeechToTextService
    {
        public bool IsAvailable { get; } = available;
        public TranscriptionMetadata? LastMetadata => null;
        public int Calls { get; private set; }
        public Task WarmAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
        public Task<string> TranscribeAsync(string audioPath, IReadOnlyList<string> hints, CancellationToken cancellationToken)
        { Calls++; return failure is null ? Task.FromResult(text) : Task.FromException<string>(failure); }
    }
}
