using SherpaOnnx;
using NAudio.Wave;
using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

/// <summary>Offline SenseVoice Cantonese/Chinese recognizer with optional Silero VAD.</summary>
public sealed class SherpaOnnxTranscriptionService : IAvailableSpeechToTextService
{
    private readonly string _modelPath;
    private readonly string _tokensPath;
    private readonly string _vadPath;
    private readonly bool _useVad;
    private readonly object _gate = new();
    private OfflineRecognizer? _recognizer;
    public TranscriptionMetadata? LastMetadata { get; private set; }

    public SherpaOnnxTranscriptionService(string modelPath, string tokensPath, string vadPath, bool useVad = true)
    {
        _modelPath = modelPath;
        _tokensPath = tokensPath;
        _vadPath = vadPath;
        _useVad = useVad;
    }

    public bool IsAvailable => File.Exists(_modelPath) && new FileInfo(_modelPath).Length >= 100_000_000 && File.Exists(_tokensPath) && (!_useVad || File.Exists(_vadPath));

    public Task WarmAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!IsAvailable) return Task.CompletedTask;
        EnsureRecognizer();
        return Task.CompletedTask;
    }

    public Task<string> TranscribeAsync(string audioPath, IReadOnlyList<string> hints, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!IsAvailable)
            throw new FileNotFoundException("Sherpa SenseVoice model or Silero VAD is not installed.");

        using var reader = new WaveFileReader(audioPath);
        if (reader.WaveFormat.SampleRate != 16_000 || reader.WaveFormat.Channels != 1 || reader.WaveFormat.BitsPerSample != 16)
            throw new InvalidDataException($"Sherpa requires a 16 kHz mono 16-bit WAV; received {reader.WaveFormat.SampleRate} Hz, {reader.WaveFormat.Channels} channels, {reader.WaveFormat.BitsPerSample} bits.");
        if (reader.Length > int.MaxValue) throw new InvalidDataException("WAV is too large.");
        var bytes = new byte[(int)reader.Length];
        var read = reader.Read(bytes, 0, bytes.Length);
        var samples = new float[read / 2];
        for (var i = 0; i < samples.Length; i++) samples[i] = BitConverter.ToInt16(bytes, i * 2) / 32768f;
        var started = System.Diagnostics.Stopwatch.StartNew();
        var audioDuration = TimeSpan.FromSeconds(samples.Length / 16_000d);
        var recognizer = EnsureRecognizer();
        var texts = new List<string>();
        var speechSamples = 0;

        if (_useVad)
        {
            var vad = CreateVad();
            const int windowSize = 512;
            for (var offset = 0; offset < samples.Length; offset += windowSize)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var window = new float[Math.Min(windowSize, samples.Length - offset)];
                Array.Copy(samples, offset, window, 0, window.Length);
                if (window.Length < windowSize) Array.Resize(ref window, windowSize);
                vad.AcceptWaveform(window);
                speechSamples += Drain(vad, recognizer, texts, cancellationToken);
            }
            vad.Flush();
            speechSamples += Drain(vad, recognizer, texts, cancellationToken);
        }
        else
        {
            var stream = recognizer.CreateStream();
            stream.AcceptWaveform(16_000, samples);
            recognizer.Decode(stream);
            texts.Add(stream.Result.Text);
            speechSamples = samples.Length;
        }

        started.Stop();
        LastMetadata = new TranscriptionMetadata("Sherpa-ONNX", Path.GetFileName(_modelPath), "Cantonese/auto", _useVad, audioDuration, TimeSpan.FromSeconds(speechSamples / 16_000d), started.Elapsed);
        return Task.FromResult(string.Join(" ", texts.Where(t => !string.IsNullOrWhiteSpace(t))).Trim());
    }

    private int Drain(VoiceActivityDetector vad, OfflineRecognizer recognizer, List<string> texts, CancellationToken cancellationToken)
    {
        var speechSamples = 0;
        while (!vad.IsEmpty())
        {
            cancellationToken.ThrowIfCancellationRequested();
            var segment = vad.Front();
            speechSamples += segment.Samples.Length;
            var stream = recognizer.CreateStream();
            stream.AcceptWaveform(16_000, segment.Samples);
            recognizer.Decode(stream);
            if (!string.IsNullOrWhiteSpace(stream.Result.Text)) texts.Add(stream.Result.Text);
            vad.Pop();
        }
        return speechSamples;
    }

    private OfflineRecognizer EnsureRecognizer()
    {
        lock (_gate)
        {
            if (_recognizer is not null) return _recognizer;
            var config = new OfflineRecognizerConfig();
            config.FeatConfig.SampleRate = 16_000;
            config.ModelConfig.Tokens = _tokensPath;
            config.ModelConfig.SenseVoice.Model = _modelPath;
            config.ModelConfig.SenseVoice.Language = "auto";
            config.ModelConfig.SenseVoice.UseInverseTextNormalization = 1;
            config.ModelConfig.NumThreads = 2;
            config.ModelConfig.Debug = 0;
            _recognizer = new OfflineRecognizer(config);
            return _recognizer;
        }
    }

    private VoiceActivityDetector CreateVad()
    {
        var config = new VadModelConfig();
        config.SileroVad.Model = _vadPath;
        config.SileroVad.Threshold = 0.3F;
        config.SileroVad.MinSilenceDuration = 0.5F;
        config.SileroVad.MinSpeechDuration = 0.25F;
        config.SileroVad.MaxSpeechDuration = 30.0F;
        config.SileroVad.WindowSize = 512;
        config.Debug = 0;
        return new VoiceActivityDetector(config, 60);
    }
}
