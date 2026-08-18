using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class PromptBuilderTests
{
    [Fact]
    public void TechnicalEnglishPromptPreservesIdentifiersAndIncludesContext()
    {
        var prompt = new PromptBuilder().BuildDictation(new ProcessingRequest(
            "fix foo_bar",
            new CapturedContext { ActiveApplicationName = "Visual Studio Code", WindowTitle = "worker.cs" },
            AppMode.Technical,
            ProcessingStyle.Technical,
            OutputLanguage.English));

        Assert.Contains("MODE: technical", prompt);
        Assert.Contains("STYLE: technical", prompt);
        Assert.Contains("never simplify or alter identifiers", prompt);
        Assert.Contains("Translate the final text into natural English", prompt);
        Assert.Contains("Visual Studio Code", prompt);
        Assert.EndsWith("RAW DICTATION:\nfix foo_bar", prompt);
    }
}
