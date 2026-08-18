using NAudio.CoreAudioApi;
using NAudio.Wave;
using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public sealed class WasapiAudioCaptureService : IAudioCaptureService
{
    private readonly object _sync = new();
    private WasapiCapture? _capture;
    private WaveFileWriter? _writer;
    private string? _audioPath;
    private TaskCompletionSource? _stopped;
    private long _bytesRecorded;

    public event EventHandler<float>? LevelChanged;

    public Task StartAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        lock (_sync)
        {
            if (_capture is not null)
                throw new InvalidOperationException("Audio capture is already running.");

            var recordings = Path.Combine(Path.GetTempPath(), "VoiceWritingAssistant", "Recordings");
            Directory.CreateDirectory(recordings);
            _audioPath = Path.Combine(recordings, $"dictation-{Guid.NewGuid():N}.wav");
            _bytesRecorded = 0;
            _capture = new WasapiCapture
            {
                ShareMode = AudioClientShareMode.Shared,
                WaveFormat = new WaveFormat(16_000, 16, 1)
            };
            _writer = new WaveFileWriter(_audioPath, _capture.WaveFormat);
            _stopped = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            _capture.DataAvailable += OnDataAvailable;
            _capture.RecordingStopped += OnRecordingStopped;
            _capture.StartRecording();
        }
        return Task.CompletedTask;
    }

    public async Task<string> StopAsync(CancellationToken cancellationToken)
    {
        WasapiCapture capture;
        Task stopped;
        string path;
        lock (_sync)
        {
            capture = _capture ?? throw new InvalidOperationException("Audio capture is not running.");
            stopped = _stopped?.Task ?? Task.CompletedTask;
            path = _audioPath ?? throw new InvalidOperationException("No recording path was created.");
            capture.StopRecording();
        }
        await stopped.WaitAsync(cancellationToken).ConfigureAwait(false);
        if (_bytesRecorded == 0 || !File.Exists(path) || new FileInfo(path).Length <= 46)
            throw new InvalidOperationException("The microphone returned no audio samples. Check the selected Windows input device and microphone permission, then try again.");
        return path;
    }

    public async Task CancelAsync()
    {
        string? path;
        Task? stopped = null;
        lock (_sync)
        {
            path = _audioPath;
            if (_capture is not null)
            {
                stopped = _stopped?.Task;
                _capture.StopRecording();
            }
        }
        if (stopped is not null)
            await stopped.ConfigureAwait(false);
        if (path is not null)
            File.Delete(path);
    }

    private void OnDataAvailable(object? sender, WaveInEventArgs eventArgs)
    {
        lock (_sync)
        {
            _writer?.Write(eventArgs.Buffer, 0, eventArgs.BytesRecorded);
            _bytesRecorded += eventArgs.BytesRecorded;
        }
        var peak = 0;
        for (var index = 0; index + 1 < eventArgs.BytesRecorded; index += 2)
            peak = Math.Max(peak, Math.Abs(BitConverter.ToInt16(eventArgs.Buffer, index)));
        LevelChanged?.Invoke(this, Math.Clamp(peak / 32768f, 0, 1));
    }

    private void OnRecordingStopped(object? sender, StoppedEventArgs eventArgs)
    {
        TaskCompletionSource? stopped;
        lock (_sync)
        {
            stopped = _stopped;
            if (_capture is not null)
            {
                _capture.DataAvailable -= OnDataAvailable;
                _capture.RecordingStopped -= OnRecordingStopped;
            }
            _writer?.Dispose();
            _capture?.Dispose();
            _writer = null;
            _capture = null;
            _stopped = null;
        }
        if (eventArgs.Exception is null)
            stopped?.TrySetResult();
        else
            stopped?.TrySetException(eventArgs.Exception);
    }

    public async ValueTask DisposeAsync() => await CancelAsync().ConfigureAwait(false);
}
