namespace VoiceWritingAssistant.Core;

public static class OutputSanitizer
{
    public static string Sanitize(string text)
    {
        var output = text.Trim();
        if (output.StartsWith("```", StringComparison.Ordinal) && output.EndsWith("```", StringComparison.Ordinal))
        {
            output = output[3..^3].Trim();
            var firstLine = output.IndexOf('\n');
            if (firstLine is > 0 and < 20 && output[..firstLine].All(char.IsLetter))
                output = output[(firstLine + 1)..].Trim();
        }
        return output;
    }
}
