using System.Diagnostics;
using System.Text.RegularExpressions;

namespace VoiceWritingAssistant.Core;

public sealed partial class RuleBasedProcessor : ITextProcessor
{
    public string Name => "Rule-based (AI unavailable)";

    public Task<ProcessingResult> ProcessAsync(ProcessingRequest request, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var stopwatch = Stopwatch.StartNew();
        var lines = request.RawText.Replace("\r\n", "\n", StringComparison.Ordinal)
            .Split('\n')
            .Select(line => HorizontalWhitespace().Replace(line, " ").Trim());
        var result = SpaceBeforePunctuation().Replace(string.Join('\n', lines), "$1").Trim();
        return Task.FromResult(new ProcessingResult(result, Name, stopwatch.Elapsed));
    }

    [GeneratedRegex(@"[ \t]+")]
    private static partial Regex HorizontalWhitespace();

    [GeneratedRegex(@"\s+([,.;:!?])")]
    private static partial Regex SpaceBeforePunctuation();
}
