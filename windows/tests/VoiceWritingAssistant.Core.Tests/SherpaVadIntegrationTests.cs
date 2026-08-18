using NAudio.Wave;
using VoiceWritingAssistant.Windows.Infrastructure;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class SherpaVadIntegrationTests
{
    [Fact]
    public async Task SilenceProducesNoTranscriptWhenOfficialModelsAreInstalled()
    {
        if (!SpeechModelManager.IsInstalled) return;
        var wav = Path.Combine(Path.GetTempPath(), "vwa-silence-" + Guid.NewGuid().ToString("N") + ".wav");
        try
        {
            using (var writer = new WaveFileWriter(wav, new WaveFormat(16_000, 16, 1))) writer.Write(new byte[16_000 * 2 * 2]);
            var service = new SherpaOnnxTranscriptionService(SpeechModelManager.DefaultModelPath, SpeechModelManager.DefaultTokensPath, SpeechModelManager.DefaultVadPath);
            Assert.Equal(string.Empty, await service.TranscribeAsync(wav, [], CancellationToken.None));
        }
        finally { File.Delete(wav); }
    }
}
