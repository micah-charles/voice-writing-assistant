using VoiceWritingAssistant.Windows.Infrastructure;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class AudioHistoryStoreTests
{
    [Fact]
    public async Task ArchivesAndRetainsOnlyTheLatestTenRecordings()
    {
        var root = Path.Combine(Path.GetTempPath(), "VoiceWritingAssistantTests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        var source = Path.Combine(root, "source.wav");
        await File.WriteAllBytesAsync(source, [0, 1, 2, 3]);
        var recordings = Path.Combine(root, "recordings");
        var store = new AudioHistoryStore(recordings);

        for (var index = 0; index < 12; index++)
            await store.ArchiveAsync(source, DateTimeOffset.UtcNow.AddSeconds(index));

        Assert.Equal(10, Directory.GetFiles(recordings, "*.wav").Length);
        Assert.All(Directory.GetFiles(recordings, "*.wav"), path => Assert.Equal([0, 1, 2, 3], File.ReadAllBytes(path)));
        await store.ClearAsync();
        Assert.Empty(Directory.GetFiles(recordings, "*.wav"));
    }
}
