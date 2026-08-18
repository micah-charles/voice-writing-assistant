using System.Text.Json;
using System.Text.Json.Serialization;
using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public static class LocalDataPaths
{
    public static string Root => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "VoiceWritingAssistant");

    public static string History => Path.Combine(Root, "history.json");
    public static string Dictionary => Path.Combine(Root, "dictionary.json");
    public static string AudioRecordings => Path.Combine(Root, "recordings");
}

public sealed class AudioHistoryStore(string? directory = null) : IAudioRecordingStore
{
    private readonly string _directory = directory ?? LocalDataPaths.AudioRecordings;
    private readonly SemaphoreSlim _gate = new(1, 1);

    public async Task<string> ArchiveAsync(string sourcePath, DateTimeOffset recordedAt, CancellationToken cancellationToken = default)
    {
        if (!File.Exists(sourcePath)) throw new FileNotFoundException("Recording was not found.", sourcePath);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            Directory.CreateDirectory(_directory);
            var destination = Path.Combine(_directory, $"recording-{recordedAt:yyyyMMdd-HHmmss}-{Guid.NewGuid():N}.wav");
            await using (var source = File.OpenRead(sourcePath))
            await using (var target = File.Create(destination))
                await source.CopyToAsync(target, cancellationToken).ConfigureAwait(false);

            foreach (var old in Directory.EnumerateFiles(_directory, "*.wav")
                .Select(path => new FileInfo(path))
                .OrderByDescending(file => file.CreationTimeUtc)
                .Skip(10))
            {
                try { old.Delete(); } catch { }
            }
            return destination;
        }
        finally { _gate.Release(); }
    }

    public async Task ClearAsync(CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (!Directory.Exists(_directory)) return;
            foreach (var path in Directory.EnumerateFiles(_directory, "*.wav"))
                try { File.Delete(path); } catch { }
        }
        finally { _gate.Release(); }
    }
}

public sealed class JsonHistoryStore : IHistoryStore
{
    private readonly string _path;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private static readonly JsonSerializerOptions Options = CreateOptions();

    public JsonHistoryStore(string? path = null) => _path = path ?? LocalDataPaths.History;

    public async Task<IReadOnlyList<HistoryEntry>> LoadAsync(CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try { return await ReadUnsafeAsync(cancellationToken).ConfigureAwait(false); }
        finally { _gate.Release(); }
    }

    public async Task AppendAsync(HistoryEntry entry, CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var entries = (await ReadUnsafeAsync(cancellationToken).ConfigureAwait(false)).ToList();
            entries.Insert(0, entry);
            await WriteUnsafeAsync(entries, cancellationToken).ConfigureAwait(false);
        }
        finally { _gate.Release(); }
    }

    public async Task UpdateAlternativesAsync(Guid id, IReadOnlyList<ProcessingResult> alternatives, CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            var entries = (await ReadUnsafeAsync(cancellationToken).ConfigureAwait(false)).ToList();
            var index = entries.FindIndex(item => item.Id == id);
            if (index < 0) return;
            entries[index] = entries[index] with { AlternativeResults = alternatives };
            await WriteUnsafeAsync(entries, cancellationToken).ConfigureAwait(false);
        }
        finally { _gate.Release(); }
    }

    public async Task ClearAsync(CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try { await WriteUnsafeAsync([], cancellationToken).ConfigureAwait(false); }
        finally { _gate.Release(); }
    }

    private async Task<IReadOnlyList<HistoryEntry>> ReadUnsafeAsync(CancellationToken cancellationToken)
    {
        if (!File.Exists(_path)) return [];
        await using var stream = File.OpenRead(_path);
        return await JsonSerializer.DeserializeAsync<List<HistoryEntry>>(stream, Options, cancellationToken).ConfigureAwait(false) ?? [];
    }

    private Task WriteUnsafeAsync(IReadOnlyList<HistoryEntry> entries, CancellationToken cancellationToken) =>
        AtomicJson.WriteAsync(_path, entries, Options, cancellationToken);

    private static JsonSerializerOptions CreateOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web) { WriteIndented = true };
        options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
        return options;
    }
}

public sealed class JsonDictionaryStore : IDictionaryStore
{
    private readonly string _path;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web) { WriteIndented = true };

    public JsonDictionaryStore(string? path = null) => _path = path ?? LocalDataPaths.Dictionary;

    public async Task<IReadOnlyList<PersonalDictionaryEntry>> LoadAsync(CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (!File.Exists(_path)) return [];
            await using var stream = File.OpenRead(_path);
            return await JsonSerializer.DeserializeAsync<List<PersonalDictionaryEntry>>(stream, Options, cancellationToken).ConfigureAwait(false) ?? [];
        }
        finally { _gate.Release(); }
    }

    public async Task SaveAsync(IReadOnlyList<PersonalDictionaryEntry> entries, CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try { await AtomicJson.WriteAsync(_path, entries, Options, cancellationToken).ConfigureAwait(false); }
        finally { _gate.Release(); }
    }
}

internal static class AtomicJson
{
    public static async Task WriteAsync<T>(string path, T value, JsonSerializerOptions options, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporaryPath = path + ".tmp";
        await using (var stream = File.Create(temporaryPath))
            await JsonSerializer.SerializeAsync(stream, value, options, cancellationToken).ConfigureAwait(false);
        File.Move(temporaryPath, path, true);
    }
}
