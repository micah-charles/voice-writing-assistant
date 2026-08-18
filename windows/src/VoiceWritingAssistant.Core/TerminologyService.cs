using System.Text.RegularExpressions;

namespace VoiceWritingAssistant.Core;

public sealed class TerminologyService
{
    public IReadOnlyList<string> BuildHints(IEnumerable<PersonalDictionaryEntry> entries) =>
        entries
            .SelectMany(entry => entry.Aliases.Append(entry.Term).Append(entry.PreferredForm))
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();

    public string Normalize(string text, IEnumerable<PersonalDictionaryEntry> entries)
    {
        var result = text;
        foreach (var entry in entries)
        {
            var aliases = entry.Aliases
                .Append(entry.Term)
                .Where(alias => !string.IsNullOrWhiteSpace(alias))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderByDescending(alias => alias.Length);

            foreach (var alias in aliases)
            {
                var pattern = IsWordLike(alias)
                    ? $@"(?<![\p{{L}}\p{{N}}_]){Regex.Escape(alias)}(?![\p{{L}}\p{{N}}_])"
                    : Regex.Escape(alias);
                result = Regex.Replace(result, pattern, entry.PreferredForm, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
            }
        }
        return result;
    }

    private static bool IsWordLike(string value) =>
        value.All(character => char.IsLetterOrDigit(character) || character == '_' || character == '-' || char.IsWhiteSpace(character));
}
