namespace VoiceWritingAssistant.Core;

public interface IAudioCaptureService : IAsyncDisposable
{
    Task StartAsync(CancellationToken cancellationToken);
    Task<string> StopAsync(CancellationToken cancellationToken);
    Task CancelAsync();
}

public interface ISpeechToTextService
{
    Task<string> TranscribeAsync(string audioPath, IReadOnlyList<string> hints, CancellationToken cancellationToken);
}

public interface IAvailableSpeechToTextService : ISpeechToTextService
{
    bool IsAvailable { get; }
    TranscriptionMetadata? LastMetadata { get; }
    Task WarmAsync(CancellationToken cancellationToken = default);
}

public interface IContextCaptureService
{
    Task<CapturedContext> CaptureAsync(CancellationToken cancellationToken);
}

public interface ITextDeliveryService
{
    Task DeliverAsync(
        string text,
        CapturedContext target,
        bool autoPaste,
        bool restoreClipboard,
        bool autoSend,
        CancellationToken cancellationToken);
    Task UndoLastAsync(CapturedContext target, CancellationToken cancellationToken);
}

public interface ITextProcessor
{
    string Name { get; }
    Task<ProcessingResult> ProcessAsync(ProcessingRequest request, CancellationToken cancellationToken);
}

public interface IHistoryStore
{
    Task AppendAsync(HistoryEntry entry, CancellationToken cancellationToken = default);
    Task UpdateAlternativesAsync(Guid id, IReadOnlyList<ProcessingResult> alternatives, CancellationToken cancellationToken = default);
}

public interface IDictionaryStore
{
    Task<IReadOnlyList<PersonalDictionaryEntry>> LoadAsync(CancellationToken cancellationToken = default);
}

public interface IAudioRecordingStore
{
    Task<string> ArchiveAsync(string sourcePath, DateTimeOffset recordedAt, CancellationToken cancellationToken = default);
}
