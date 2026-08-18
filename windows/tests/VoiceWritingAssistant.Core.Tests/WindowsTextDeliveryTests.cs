using System.Globalization;
using System.Threading;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Threading;
using VoiceWritingAssistant.Core;
using VoiceWritingAssistant.Windows.Infrastructure;
using TextBox = System.Windows.Controls.TextBox;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class WindowsTextDeliveryTests
{
    [Fact]
    public async Task DeliveryTargetsOriginalWindowAndRestoresClipboard()
    {
        var completion = new TaskCompletionSource<(string Text, string Clipboard)>(TaskCreationOptions.RunContinuationsAsynchronously);
        var thread = new Thread(() => RunDeliveryWindow(completion)) { IsBackground = true };
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();

        var result = await completion.Task.WaitAsync(TimeSpan.FromSeconds(12));
        Assert.True(thread.Join(TimeSpan.FromSeconds(2)));
        Assert.Equal("Delivered text", result.Text);
        Assert.Equal("original clipboard", result.Clipboard);
    }

    private static void RunDeliveryWindow(TaskCompletionSource<(string Text, string Clipboard)> completion)
    {
        var dispatcher = Dispatcher.CurrentDispatcher;
        var textBox = new TextBox { Width = 420, Height = 120, AcceptsReturn = true };
        var window = new Window { Title = "Delivery integration target", Width = 480, Height = 220, Content = textBox, ShowInTaskbar = false };
        window.Loaded += async (_, _) =>
        {
            try
            {
                _ = textBox.Focus();
                Clipboard.SetText("original clipboard");
                var handle = new WindowInteropHelper(window).Handle;
                var target = new CapturedContext { PlatformTargetId = handle.ToString("X", CultureInfo.InvariantCulture) };
                await new WindowsTextDeliveryService(dispatcher).DeliverAsync("Delivered text", target, true, true, false, CancellationToken.None);
                await Task.Delay(200);
                completion.TrySetResult((textBox.Text, Clipboard.GetText()));
            }
            catch (Exception exception) { completion.TrySetException(exception); }
            finally { window.Close(); dispatcher.BeginInvokeShutdown(DispatcherPriority.Background); }
        };
        window.Show();
        Dispatcher.Run();
    }
}
