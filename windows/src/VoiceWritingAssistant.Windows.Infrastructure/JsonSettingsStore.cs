using System.Text.Json;
using System.Text.Json.Serialization;
using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public static class JsonSettingsStore
{
    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
    };

    public static string SettingsPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "VoiceWritingAssistant",
        "settings.json");

    public static Task<AppSettings> LoadAsync(CancellationToken cancellationToken = default) =>
        LoadAsync(SettingsPath, cancellationToken);

    public static async Task<AppSettings> LoadAsync(string path, CancellationToken cancellationToken = default)
    {
        if (File.Exists(path))
        {
            var json = await File.ReadAllTextAsync(path, cancellationToken).ConfigureAwait(false);
            return JsonSerializer.Deserialize<AppSettings>(json, Options) ?? new AppSettings();
        }

        var settings = new AppSettings
        {
            WhisperModelPath = Path.Combine(Path.GetDirectoryName(path)!, "models", "ggml-small.bin")
        };
        await SaveAsync(path, settings, cancellationToken).ConfigureAwait(false);
        return settings;
    }

    public static Task SaveAsync(AppSettings settings, CancellationToken cancellationToken = default) =>
        SaveAsync(SettingsPath, settings, cancellationToken);

    public static async Task SaveAsync(string path, AppSettings settings, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(settings);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporaryPath = path + ".tmp";
        await File.WriteAllTextAsync(
            temporaryPath,
            JsonSerializer.Serialize(settings, Options),
            cancellationToken).ConfigureAwait(false);
        File.Move(temporaryPath, path, true);
    }
}
