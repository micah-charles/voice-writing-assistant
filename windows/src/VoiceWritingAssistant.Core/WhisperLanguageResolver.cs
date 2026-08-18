namespace VoiceWritingAssistant.Core;

public enum WhisperModelLanguageCapability { LegacyMultilingual, ExplicitCantoneseYue }

public static class WhisperLanguageResolver
{
    public static string? Resolve(RecognitionLanguage language, WhisperModelLanguageCapability capability = WhisperModelLanguageCapability.LegacyMultilingual) => language switch
    {
        RecognitionLanguage.English => "en",
        RecognitionLanguage.TraditionalChinese or RecognitionLanguage.Cantonese or RecognitionLanguage.MixedChineseEnglish
            => capability == WhisperModelLanguageCapability.ExplicitCantoneseYue && language == RecognitionLanguage.Cantonese ? "yue" : "zh",
        _ => null
    };
}
