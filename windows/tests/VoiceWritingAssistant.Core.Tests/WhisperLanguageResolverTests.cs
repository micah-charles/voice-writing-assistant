using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class WhisperLanguageResolverTests
{
    [Fact] public void LegacyCantoneseUsesChineseToken() => Assert.Equal("zh", WhisperLanguageResolver.Resolve(RecognitionLanguage.Cantonese));
    [Fact] public void ExplicitYueCapabilityCanUseYue() => Assert.Equal("yue", WhisperLanguageResolver.Resolve(RecognitionLanguage.Cantonese, WhisperModelLanguageCapability.ExplicitCantoneseYue));
    [Fact] public void AutomaticLeavesLanguageUnspecified() => Assert.Null(WhisperLanguageResolver.Resolve(RecognitionLanguage.Automatic));
}
