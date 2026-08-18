using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class ProcessorRouterTests
{
    [Fact]
    public async Task FallsBackAfterProviderFailure()
    {
        var router = new ProcessorRouter([new FailingProcessor()], new RuleBasedProcessor());
        var result = await router.ProcessAsync(
            new ProcessingRequest("hello   world !", new CapturedContext(), AppMode.General, ProcessingStyle.Automatic, OutputLanguage.PreserveSpokenLanguage),
            CancellationToken.None);

        Assert.Equal("hello world!", result.Text);
        Assert.True(result.UsedFallback);
        Assert.Contains("Rule-based", result.Provider);
    }

    [Fact]
    public async Task AutomaticRaceReturnsFirstSuccessfulProvider()
    {
        var router = new ProcessorRouter(
            [new DelayedProcessor("slow", 80), new DelayedProcessor("fast", 5)],
            new RuleBasedProcessor(),
            raceFirst: true);

        var result = await router.ProcessAsync(
            new ProcessingRequest("hello", new CapturedContext(), AppMode.General, ProcessingStyle.Automatic, OutputLanguage.PreserveSpokenLanguage),
            CancellationToken.None);

        Assert.Equal("fast", result.Provider);
    }

    private sealed class DelayedProcessor(string name, int delay) : ITextProcessor
    {
        public string Name => name;
        public async Task<ProcessingResult> ProcessAsync(ProcessingRequest request, CancellationToken cancellationToken)
        {
            await Task.Delay(delay, cancellationToken);
            return new ProcessingResult(name, name, TimeSpan.FromMilliseconds(delay));
        }
    }

    private sealed class FailingProcessor : ITextProcessor
    {
        public string Name => "Failure";
        public Task<ProcessingResult> ProcessAsync(ProcessingRequest request, CancellationToken cancellationToken) =>
            throw new InvalidOperationException("Unavailable");
    }
}
