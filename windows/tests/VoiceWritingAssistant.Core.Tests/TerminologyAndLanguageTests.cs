using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class TerminologyAndLanguageTests
{
    [Fact]
    public void DictionaryNormalizesAliasesWithoutReplacingInsideWords()
    {
        var service = new TerminologyService();
        var entries = new[] { new PersonalDictionaryEntry { Term = "cod ex", PreferredForm = "Codex", Aliases = ["code x", "cod ex"] } };

        var result = service.Normalize("Use code x, not code xyz.", entries);

        Assert.Equal("Use Codex, not code xyz.", result);
        Assert.Contains("Codex", service.BuildHints(entries));
    }

    [Fact]
    public void ChineseConversionSupportsTraditionalAndTaiwanProfiles()
    {
        var service = new ChineseConversionService();

        Assert.Equal("漢字轉換", service.Convert("汉字转换", OpenCcProfile.Traditional));
        Assert.Contains("軟體", service.Convert("软件", OpenCcProfile.TaiwanTraditional));
    }
}
