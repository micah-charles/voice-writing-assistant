using VoiceWritingAssistant.Windows.Infrastructure;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class SpeechModelManagerTests
{
    [Fact]
    public void MissingAndPartialModelsAreNotInstalled()
    {
        var root = Path.Combine(Path.GetTempPath(), "vwa-model-test-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(root);
        try
        {
            Assert.False(SpeechModelManager.VerifyInstalled(root));
            File.WriteAllBytes(Path.Combine(root, "tokens.txt"), new byte[2000]); File.WriteAllBytes(Path.Combine(root, "silero_vad.onnx"), new byte[101_000]);
            using (var stream = File.Create(Path.Combine(root, "model.int8.onnx"))) stream.SetLength(99_999_999);
            Assert.False(SpeechModelManager.VerifyInstalled(root));
        }
        finally { Directory.Delete(root, true); }
    }
}
