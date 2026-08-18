using VoiceWritingAssistant.Core;
using VoiceWritingAssistant.Windows.Infrastructure;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class LocalStoreTests
{
    [Fact]
    public async Task SettingsRoundTripIncludesParityOptions()
    {
        var path = TemporaryFile("settings");
        try
        {
            var expected = new AppSettings
            {
                ShortcutMode = ShortcutMode.Toggle, ReviewBeforePaste = true, UseBrowserUrl = true,
                StoreHistory = true, RecognitionLanguage = RecognitionLanguage.Cantonese,
                OpenCcProfile = OpenCcProfile.TaiwanTraditional
            };
            await JsonSettingsStore.SaveAsync(path, expected);

            var actual = await JsonSettingsStore.LoadAsync(path);

            Assert.Equal(expected.ShortcutMode, actual.ShortcutMode);
            Assert.True(actual.ReviewBeforePaste);
            Assert.True(actual.UseBrowserUrl);
            Assert.Equal(RecognitionLanguage.Cantonese, actual.RecognitionLanguage);
            Assert.Equal(OpenCcProfile.TaiwanTraditional, actual.OpenCcProfile);
        }
        finally { Delete(path); Delete(path + ".tmp"); }
    }

    [Fact]
    public async Task LegacyWindowsSettingsGainNewDefaultsWithoutLosingPaths()
    {
        var path = TemporaryFile("legacy-settings");
        try
        {
            await File.WriteAllTextAsync(path, """{"autoPaste":false,"whisperModelPath":"C:\\models\\base.bin","ollamaModel":"qwen"}""");

            var settings = await JsonSettingsStore.LoadAsync(path);

            Assert.False(settings.AutoPaste);
            Assert.Equal(@"C:\models\base.bin", settings.WhisperModelPath);
            Assert.Equal("qwen", settings.OllamaModel);
            Assert.True(settings.ShowFloatingControl);
            Assert.True(settings.StoreHistory);
            Assert.Equal(ShortcutMode.PushToTalk, settings.ShortcutMode);
        }
        finally { Delete(path); Delete(path + ".tmp"); }
    }

    [Fact]
    public async Task HistoryAndDictionaryPersistLocally()
    {
        var historyPath = TemporaryFile("history"); var dictionaryPath = TemporaryFile("dictionary");
        try
        {
            var history = new JsonHistoryStore(historyPath);
            var id = Guid.NewGuid();
            await history.AppendAsync(new HistoryEntry { Id = id, RawTranscript = "raw", ProcessedText = "final", Provider = "test" });
            await history.UpdateAlternativesAsync(id, [new ProcessingResult("other", "alternate", TimeSpan.FromSeconds(1))]);
            Assert.Single((await history.LoadAsync()).Single().AlternativeResults);

            var dictionary = new JsonDictionaryStore(dictionaryPath);
            await dictionary.SaveAsync([new PersonalDictionaryEntry { Term = "code x", PreferredForm = "Codex", Aliases = ["code x"] }]);
            Assert.Equal("Codex", (await dictionary.LoadAsync()).Single().PreferredForm);
        }
        finally { Delete(historyPath); Delete(historyPath + ".tmp"); Delete(dictionaryPath); Delete(dictionaryPath + ".tmp"); }
    }

    private static string TemporaryFile(string name) => Path.Combine(Path.GetTempPath(), $"vwa-{name}-{Guid.NewGuid():N}.json");
    private static void Delete(string path) { if (File.Exists(path)) File.Delete(path); }
}
