using System.Diagnostics;
using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public sealed class CodexCliTextProcessor(string executable, TimeSpan timeout) : ITextProcessor
{
    private readonly PromptBuilder _prompts = new();
    public string Name => "Codex CLI";

    public async Task<ProcessingResult> ProcessAsync(ProcessingRequest request, CancellationToken cancellationToken)
    {
        var stopwatch = Stopwatch.StartNew();
        var output = await ProcessRunner.RunAsync(
            executable,
            ["exec", "--ephemeral", "--skip-git-repo-check", "--sandbox", "read-only", "-"],
            _prompts.BuildDictation(request),
            timeout,
            cancellationToken).ConfigureAwait(false);
        if (output.ExitCode != 0)
            throw new InvalidOperationException(string.IsNullOrWhiteSpace(output.StandardError) ? "Codex CLI failed." : output.StandardError.Trim());
        return new ProcessingResult(OutputSanitizer.Sanitize(output.StandardOutput), Name, stopwatch.Elapsed);
    }
}
