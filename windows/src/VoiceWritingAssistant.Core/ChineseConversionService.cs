using OpenccNetLib;

namespace VoiceWritingAssistant.Core;

public sealed class ChineseConversionService
{
    private readonly Lazy<Opencc> _traditional = new(() => new Opencc(OpenccConfig.S2T));
    private readonly Lazy<Opencc> _taiwan = new(() => new Opencc(OpenccConfig.S2Twp));

    public string Convert(string text, OpenCcProfile profile) => profile switch
    {
        OpenCcProfile.Traditional => _traditional.Value.Convert(text),
        OpenCcProfile.TaiwanTraditional => _taiwan.Value.Convert(text),
        _ => text
    };
}
