using System.Diagnostics;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public static class SpeechModelManager
{
    public const string SenseVoiceArchiveUrl = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09.tar.bz2";
    public const string SileroVadUrl = "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx";

    public static string DefaultRoot => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "VoiceWritingAssistant", "models", "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09");
    public static string DefaultModelPath => Path.Combine(DefaultRoot, "model.int8.onnx");
    public static string DefaultTokensPath => Path.Combine(DefaultRoot, "tokens.txt");
    public static string DefaultVadPath => Path.Combine(DefaultRoot, "silero_vad.onnx");

    public static bool IsInstalled => VerifyInstalled();

    public static bool VerifyInstalled(string? root = null)
    {
        root ??= DefaultRoot;
        var model = Path.Combine(root, "model.int8.onnx");
        var tokens = Path.Combine(root, "tokens.txt");
        var vad = Path.Combine(root, "silero_vad.onnx");
        return File.Exists(model) && new FileInfo(model).Length >= 100_000_000 && File.Exists(tokens) && new FileInfo(tokens).Length > 1_000 && File.Exists(vad) && new FileInfo(vad).Length > 100_000;
    }

    public static async Task DownloadAsync(IProgress<double>? progress = null, CancellationToken cancellationToken = default)
    {
        var parent = Path.GetDirectoryName(DefaultRoot)!;
        Directory.CreateDirectory(parent);
        var tempArchive = Path.Combine(Path.GetTempPath(), $"VoiceWritingAssistant-{Guid.NewGuid():N}.tar.bz2");
        try
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(15) };
            using var response = await client.GetAsync(SenseVoiceArchiveUrl, HttpCompletionOption.ResponseHeadersRead, cancellationToken).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();
            var total = response.Content.Headers.ContentLength ?? -1;
            await using (var input = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false))
            await using (var output = File.Create(tempArchive))
            {
                var buffer = new byte[1024 * 128]; long received = 0; int read;
                while ((read = await input.ReadAsync(buffer, cancellationToken).ConfigureAwait(false)) > 0)
                {
                    await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false);
                    received += read; if (total > 0) progress?.Report(received / (double)total * .9);
                }
            }

            var extracted = await ExtractArchiveAsync(tempArchive, parent, cancellationToken).ConfigureAwait(false);
            if (!File.Exists(DefaultVadPath)) await DownloadFileAsync(SileroVadUrl, DefaultVadPath, progress, cancellationToken).ConfigureAwait(false);
            if (!VerifyInstalled(extracted)) throw new InvalidDataException("Downloaded SenseVoice model failed verification.");
            progress?.Report(1);
        }
        finally { try { File.Delete(tempArchive); } catch { } }
    }

    private static async Task DownloadFileAsync(string url, string destination, IProgress<double>? progress, CancellationToken cancellationToken)
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromMinutes(10) };
        using var response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cancellationToken).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        await using var input = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
        await using var output = File.Create(destination);
        var buffer = new byte[64 * 1024]; int read; long received = 0; var total = response.Content.Headers.ContentLength ?? -1;
        while ((read = await input.ReadAsync(buffer, cancellationToken).ConfigureAwait(false)) > 0)
        { await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken).ConfigureAwait(false); received += read; if (total > 0) progress?.Report(.9 + received / (double)total * .1); }
    }

    private static async Task<string> ExtractArchiveAsync(string archive, string parent, CancellationToken cancellationToken)
    {
        var expected = DefaultRoot;
        var start = new ProcessStartInfo("tar", $"-xjf \"{archive}\" -C \"{parent}\"") { UseShellExecute = false, CreateNoWindow = true, RedirectStandardError = true };
        using var process = Process.Start(start) ?? throw new InvalidOperationException("Unable to start Windows tar for model extraction.");
        await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);
        if (process.ExitCode != 0) throw new InvalidDataException((await process.StandardError.ReadToEndAsync(cancellationToken).ConfigureAwait(false)).Trim());
        return expected;
    }
}
