namespace VoiceWritingAssistant.Core;

public sealed class ProcessorRouter(IEnumerable<ITextProcessor> processors, ITextProcessor fallback, bool raceFirst = false)
{
    private readonly IReadOnlyList<ITextProcessor> _processors = processors.ToArray();
    private readonly object _raceSync = new();
    private ProcessingRequest? _lastRaceRequest;
    private IReadOnlyDictionary<string, Task<ProcessingResult?>> _lastRaceTasks = new Dictionary<string, Task<ProcessingResult?>>();

    public async Task<ProcessingResult> ProcessAsync(ProcessingRequest request, CancellationToken cancellationToken)
    {
        if (raceFirst && _processors.Count > 1)
            return await ProcessRaceAsync(request, cancellationToken).ConfigureAwait(false);

        var failures = 0;
        foreach (var processor in _processors)
        {
            try
            {
                var result = await processor.ProcessAsync(request, cancellationToken).ConfigureAwait(false);
                if (!string.IsNullOrWhiteSpace(result.Text))
                    return result with { Text = OutputSanitizer.Sanitize(result.Text), UsedFallback = failures > 0 };
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch
            {
                failures++;
            }
        }

        var fallbackResult = await fallback.ProcessAsync(request, cancellationToken).ConfigureAwait(false);
        return fallbackResult with { UsedFallback = _processors.Count > 0 };
    }

    private async Task<ProcessingResult> ProcessRaceAsync(ProcessingRequest request, CancellationToken cancellationToken)
    {
        var raceTasks = _processors.ToDictionary(processor => processor.Name, processor => TryProcessAsync(processor, request, cancellationToken), StringComparer.OrdinalIgnoreCase);
        lock (_raceSync) { _lastRaceRequest = request; _lastRaceTasks = raceTasks; }
        var pending = raceTasks.Values.ToList();
        while (pending.Count > 0)
        {
            var completed = await Task.WhenAny(pending).ConfigureAwait(false);
            pending.Remove(completed);
            var result = await completed.ConfigureAwait(false);
            if (result is not null && !string.IsNullOrWhiteSpace(result.Text))
                return result with { Text = OutputSanitizer.Sanitize(result.Text) };
        }
        var fallbackResult = await fallback.ProcessAsync(request, cancellationToken).ConfigureAwait(false);
        return fallbackResult with { UsedFallback = true };
    }

    public async Task<IReadOnlyList<ProcessingResult>> GetAlternativesAsync(
        ProcessingRequest request,
        string selectedProvider,
        CancellationToken cancellationToken)
    {
        Task<ProcessingResult?>[] tasks;
        lock (_raceSync)
        {
            tasks = ReferenceEquals(_lastRaceRequest, request)
                ? _lastRaceTasks.Where(pair => !pair.Key.Equals(selectedProvider, StringComparison.OrdinalIgnoreCase)).Select(pair => pair.Value).ToArray()
                : [];
        }
        if (tasks.Length == 0)
            tasks = _processors
                .Where(processor => !processor.Name.Equals(selectedProvider, StringComparison.OrdinalIgnoreCase))
                .Select(processor => TryProcessAsync(processor, request, cancellationToken))
                .ToArray();
        if (tasks.Length == 0) return [];
        var results = await Task.WhenAll(tasks).ConfigureAwait(false);
        return results
            .Where(result => result is not null)
            .Select(result => result! with { Text = OutputSanitizer.Sanitize(result!.Text) })
            .Where(result => !string.IsNullOrWhiteSpace(result.Text))
            .ToArray();
    }

    private static async Task<ProcessingResult?> TryProcessAsync(ITextProcessor processor, ProcessingRequest request, CancellationToken cancellationToken)
    {
        try { return await processor.ProcessAsync(request, cancellationToken).ConfigureAwait(false); }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
        catch { return null; }
    }
}
