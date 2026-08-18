namespace VoiceWritingAssistant.Core;

public sealed class PromptBuilder
{
    public string BuildDictation(ProcessingRequest request)
    {
        var lines = new List<string>
        {
            "You are a careful voice dictation editor.",
            "Transform the user's raw speech into clean written text suitable for the current context.",
            "Rules:",
            "- Preserve the user's original meaning.",
            "- Do not invent facts, names, dates, commitments, prices, decisions, greetings, or sign-offs.",
            "- Remove filler words and false starts; fix punctuation and grammar.",
            "- Preserve technical terms, code identifiers, paths, acronyms, proper nouns, and mixed Chinese/English.",
            "- Return only the final text.",
            $"MODE: {ToContractValue(request.Mode)}",
            $"STYLE: {ToContractValue(request.Style)}"
        };

        lines.Add(request.Mode switch
        {
            AppMode.SelectedTextTransform => "SELECTED TEXT TRANSFORM MODE: transform SELECTED CONTEXT according to RAW DICTATION. Return only the transformed selected text.",
            AppMode.Email => "EMAIL MODE: professional, natural, concise; do not invent a recipient or sign-off.",
            AppMode.Chat => "CHAT MODE: conversational, compact, and natural.",
            AppMode.Technical => "TECHNICAL MODE: never simplify or alter identifiers, commands, paths, or acronyms.",
            AppMode.Document => "DOCUMENT MODE: use complete, readable prose.",
            AppMode.Note => "NOTE MODE: concise shorthand or bullets are acceptable when natural.",
            _ => "GENERAL MODE: use clear, natural prose."
        });

        lines.Add(request.OutputLanguage switch
        {
            OutputLanguage.English => "OUTPUT LANGUAGE: Translate the final text into natural English. Preserve proper nouns, product names, technical terms, code identifiers, commands, and paths unchanged.",
            OutputLanguage.CantoneseWritten => "OUTPUT LANGUAGE: Return polished Cantonese written in Traditional Chinese. Preserve English product and technical terms.",
            OutputLanguage.FormalTraditionalChinese => "OUTPUT LANGUAGE: Return polished formal Traditional Chinese. Preserve English product and technical terms.",
            _ => "OUTPUT LANGUAGE: Preserve the user's spoken language. Do not translate unless explicitly instructed."
        });

        Append(lines, "ACTIVE APP", request.Context.ActiveApplicationName);
        Append(lines, "WINDOW TITLE", request.Context.WindowTitle);
        Append(lines, "SELECTED CONTEXT", request.Context.SelectedText);
        Append(lines, "CLIPBOARD CONTEXT", request.Context.ClipboardText);
        Append(lines, "BROWSER URL", request.Context.BrowserUrl);
        lines.Add("RAW DICTATION:");
        lines.Add(request.RawText);
        return string.Join('\n', lines);
    }

    private static void Append(ICollection<string> lines, string label, string? value)
    {
        if (!string.IsNullOrWhiteSpace(value))
        {
            lines.Add(label + ":");
            lines.Add(value);
        }
    }

    private static string ToContractValue<T>(T value) where T : Enum
    {
        var text = value.ToString();
        return char.ToLowerInvariant(text[0]) + text[1..];
    }
}
