using VoiceWritingAssistant.Core;
using NAudio.Wave;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public sealed class WhisperCppTranscriptionService(
    string executable,
    string modelPath,
    TimeSpan timeout,
    RecognitionLanguage language = RecognitionLanguage.Automatic) : IAvailableSpeechToTextService
{
    public bool IsAvailable => !string.IsNullOrWhiteSpace(modelPath) && File.Exists(modelPath);
    public TranscriptionMetadata? LastMetadata { get; private set; }
    public async Task WarmAsync(CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(modelPath) || !File.Exists(modelPath)) return;
        var audioPath = Path.Combine(Path.GetTempPath(), "VoiceWritingAssistant", $"warm-{Guid.NewGuid():N}.wav");
        Directory.CreateDirectory(Path.GetDirectoryName(audioPath)!);
        using (var writer = new WaveFileWriter(audioPath, new WaveFormat(16_000, 16, 1)))
            writer.Write(new byte[3_200]);
        try { _ = await TranscribeAsync(audioPath, [], cancellationToken).ConfigureAwait(false); }
        catch { if (File.Exists(audioPath)) File.Delete(audioPath); }
    }

    public async Task<string> TranscribeAsync(string audioPath, IReadOnlyList<string> hints, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(modelPath) || !File.Exists(modelPath))
            throw new FileNotFoundException(
                "Set whisperModelPath in %LOCALAPPDATA%\\VoiceWritingAssistant\\settings.json before dictating.",
                modelPath);

        var started = System.Diagnostics.Stopwatch.StartNew();
        var audioDuration = GetDuration(audioPath);
        var outputBase = Path.Combine(Path.GetTempPath(), "VoiceWritingAssistant", $"transcript-{Guid.NewGuid():N}");
        var outputText = outputBase + ".txt";
        try
        {
            var arguments = new List<string> { "-m", modelPath, "-f", audioPath, "-otxt", "-of", outputBase, "-np" };
            // Legacy Whisper models do not reliably support the yue token;
            // the central resolver maps Cantonese to zh for this capability.
            var languageCode = WhisperLanguageResolver.Resolve(language);
            if (languageCode is not null) { arguments.Add("-l"); arguments.Add(languageCode); }
            if (hints.Count > 0) { arguments.Add("--prompt"); arguments.Add(string.Join(", ", hints)); }
            var output = await ProcessRunner.RunAsync(
                executable,
                arguments,
                null,
                timeout,
                cancellationToken).ConfigureAwait(false);
            if (output.ExitCode != 0)
                throw new InvalidOperationException(string.IsNullOrWhiteSpace(output.StandardError)
                    ? "whisper-cli failed to transcribe the recording."
                    : output.StandardError.Trim());

            var text = File.Exists(outputText)
                ? await File.ReadAllTextAsync(outputText, cancellationToken).ConfigureAwait(false)
                : output.StandardOutput;
            started.Stop();
            LastMetadata = new TranscriptionMetadata("Whisper.cpp", Path.GetFileName(modelPath), language.ToString(), false, audioDuration, audioDuration, started.Elapsed);
            return text.Trim();
        }
        finally
        {
            File.Delete(audioPath);
            File.Delete(outputText);
        }
    }

    private static TimeSpan GetDuration(string path)
    { try { using var reader = new WaveFileReader(path); return reader.TotalTime; } catch { return TimeSpan.Zero; } }
}
