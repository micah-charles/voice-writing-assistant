using System.Text.Json;
using System.Text.Json.Serialization;

namespace VoiceWritingAssistant.Core;

public sealed class ProfileCatalog
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
    };

    private readonly IReadOnlyList<AppProfile> _profiles;

    public ProfileCatalog(IEnumerable<AppProfile> profiles) => _profiles = profiles.ToArray();

    public static ProfileCatalog FromJson(string json)
    {
        var document = JsonSerializer.Deserialize<AppProfileDocument>(json, JsonOptions)
            ?? throw new InvalidDataException("The app-profile document is empty.");
        if (document.Version != 1)
            throw new InvalidDataException($"Unsupported app-profile version: {document.Version}.");
        return new ProfileCatalog(document.Profiles);
    }

    public AppProfile? Resolve(CapturedContext context) => _profiles.FirstOrDefault(profile =>
        Contains(profile.Match.ApplicationNames, context.ActiveApplicationName) ||
        Contains(profile.Match.BundleIdentifiers, context.ApplicationIdentifier) ||
        Contains(profile.Match.ExecutableNames, context.ExecutableName));

    private static bool Contains(IEnumerable<string> values, string? candidate) =>
        !string.IsNullOrWhiteSpace(candidate) &&
        values.Any(value => candidate.Contains(value, StringComparison.OrdinalIgnoreCase));
}
