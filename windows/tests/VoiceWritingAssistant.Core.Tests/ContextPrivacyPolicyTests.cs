using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class ContextPrivacyPolicyTests
{
    private static readonly CapturedContext Raw = new()
    {
        ActiveApplicationName = "Browser", ApplicationIdentifier = "browser.id", ExecutableName = "browser.exe",
        WindowTitle = "Private title", SelectedText = "selected secret", ClipboardText = "clipboard secret",
        BrowserUrl = "https://example.test/private", PlatformTargetId = "ABCD"
    };

    [Fact]
    public void DisabledContextFieldsAreRemovedButPasteTargetIsPreserved()
    {
        var filtered = new ContextPrivacyPolicy().Filter(Raw, new AppSettings
        {
            UseActiveAppContext = false, UseWindowTitle = false, UseSelectedTextContext = false,
            UseClipboardContext = false, UseBrowserUrl = false
        });

        Assert.Null(filtered.ActiveApplicationName); Assert.Null(filtered.ExecutableName); Assert.Null(filtered.WindowTitle);
        Assert.Null(filtered.SelectedText); Assert.Null(filtered.ClipboardText); Assert.Null(filtered.BrowserUrl);
        Assert.Equal("ABCD", filtered.PlatformTargetId);
    }

    [Fact]
    public void EnabledTextContextIsLengthLimited()
    {
        var filtered = new ContextPrivacyPolicy().Filter(Raw, new AppSettings
        {
            UseSelectedTextContext = true, UseClipboardContext = true, ClipboardCharacterLimit = 8
        });

        Assert.Equal("selected", filtered.SelectedText);
        Assert.Equal("clipboar", filtered.ClipboardText);
    }
}
