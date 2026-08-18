using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class ProfileCatalogTests
{
    private static ProfileCatalog LoadCatalog()
    {
        var path = Path.Combine(AppContext.BaseDirectory, "Shared", "default-app-profiles.json");
        return ProfileCatalog.FromJson(File.ReadAllText(path));
    }

    [Fact]
    public void ResolvesWindowsExecutableUsingSharedProfile()
    {
        var profile = LoadCatalog().Resolve(new CapturedContext { ExecutableName = "Code.exe" });

        Assert.NotNull(profile);
        Assert.Equal("technical", profile.Id);
        Assert.Equal(AppMode.Technical, profile.Mode);
        Assert.Equal(ProcessingStyle.Technical, profile.Style);
    }

    [Fact]
    public void AutoSendIsDisabledInEveryDefaultProfile()
    {
        var json = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Shared", "default-app-profiles.json"));
        var document = System.Text.Json.JsonDocument.Parse(json);
        var values = document.RootElement.GetProperty("profiles").EnumerateArray()
            .Select(profile => profile.GetProperty("autoSend").GetBoolean());

        Assert.All(values, Assert.False);
    }
}
