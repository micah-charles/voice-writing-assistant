using System.Diagnostics;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json.Serialization;
using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public sealed class OllamaTextProcessor(string endpoint, string model, TimeSpan timeout) : ITextProcessor
{
    private readonly HttpClient _http = new() { BaseAddress = new Uri(endpoint), Timeout = timeout };
    private readonly PromptBuilder _prompts = new();
    public string Name => "Ollama";

    public async Task<ProcessingResult> ProcessAsync(ProcessingRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(model))
            throw new InvalidOperationException("Choose an Ollama model in settings.json.");

        var stopwatch = Stopwatch.StartNew();
        using var response = await _http.PostAsJsonAsync(
            "api/chat",
            new OllamaRequest(model, false, false, [new OllamaMessage("user", _prompts.BuildDictation(request))]),
            cancellationToken).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<OllamaResponse>(cancellationToken).ConfigureAwait(false)
            ?? throw new InvalidOperationException("Ollama returned an empty response.");
        return new ProcessingResult(OutputSanitizer.Sanitize(result.Message.Content), Name, stopwatch.Elapsed);
    }

    private sealed record OllamaRequest(string Model, bool Stream, bool Think, IReadOnlyList<OllamaMessage> Messages);
    private sealed record OllamaMessage(string Role, string Content);
    private sealed record OllamaResponse(OllamaMessage Message);
}
