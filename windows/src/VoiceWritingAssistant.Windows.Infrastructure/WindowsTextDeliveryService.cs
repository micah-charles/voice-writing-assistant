using System.Globalization;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Threading;
using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public sealed class WindowsTextDeliveryService(Dispatcher dispatcher) : ITextDeliveryService
{
    public async Task DeliverAsync(
        string text,
        CapturedContext target,
        bool autoPaste,
        bool restoreClipboard,
        bool autoSend,
        CancellationToken cancellationToken)
    {
        System.Windows.DataObject? previous = null;
        await dispatcher.InvokeAsync(() =>
        {
            if (autoPaste && restoreClipboard)
                previous = SnapshotClipboard();
            Clipboard.SetText(text);
        }, DispatcherPriority.Send, cancellationToken);

        if (!autoPaste)
            return;

        if (nint.TryParse(target.PlatformTargetId, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var window))
        {
            _ = SetForegroundWindow(window);
            await Task.Delay(180, cancellationToken).ConfigureAwait(false);
        }

        SendChord(VirtualKey.Control, VirtualKey.V);
        if (autoSend)
        {
            await Task.Delay(100, cancellationToken).ConfigureAwait(false);
            SendKey(VirtualKey.Return);
        }

        if (restoreClipboard && previous is not null)
        {
            await Task.Delay(500, cancellationToken).ConfigureAwait(false);
            await dispatcher.InvokeAsync(() => Clipboard.SetDataObject(previous, true), DispatcherPriority.Send, cancellationToken);
        }
    }

    public async Task UndoLastAsync(CapturedContext target, CancellationToken cancellationToken)
    {
        if (nint.TryParse(target.PlatformTargetId, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var window))
        {
            _ = SetForegroundWindow(window);
            await Task.Delay(180, cancellationToken).ConfigureAwait(false);
        }
        SendChord(VirtualKey.Control, VirtualKey.Z);
        await Task.Delay(120, cancellationToken).ConfigureAwait(false);
    }

    private static System.Windows.DataObject? SnapshotClipboard()
    {
        var source = Clipboard.GetDataObject();
        if (source is null)
            return null;

        var snapshot = new System.Windows.DataObject();
        foreach (var format in source.GetFormats(autoConvert: false))
        {
            try
            {
                var value = source.GetData(format, autoConvert: false);
                if (value is not null)
                    snapshot.SetData(format, value);
            }
            catch
            {
                // Some delayed-rendered clipboard formats cannot be materialized. Preserve the rest.
            }
        }
        return snapshot;
    }

    private static void SendChord(VirtualKey modifier, VirtualKey key)
    {
        SendKeys((modifier, false), (key, false), (key, true), (modifier, true));
    }

    private static void SendKey(VirtualKey key)
    {
        SendKeys((key, false), (key, true));
    }

    private static void SendKeys(params (VirtualKey Key, bool KeyUp)[] strokes)
    {
        // INPUT is 40 bytes with its union at offset 8 in a 64-bit process, and
        // 28 bytes with the union at offset 4 in a 32-bit process. Describing only
        // KEYBDINPUT as a managed union loses the native union's pointer alignment,
        // so write the small native buffer explicitly for both architectures.
        var inputSize = IntPtr.Size == 8 ? 40 : 28;
        var unionOffset = IntPtr.Size == 8 ? 8 : 4;
        var buffer = Marshal.AllocHGlobal(inputSize * strokes.Length);
        uint sent;
        int error;
        try
        {
            Marshal.Copy(new byte[inputSize * strokes.Length], 0, buffer, inputSize * strokes.Length);
            for (var index = 0; index < strokes.Length; index++)
            {
                var input = IntPtr.Add(buffer, index * inputSize);
                Marshal.WriteInt32(input, 0, 1); // INPUT_KEYBOARD
                Marshal.WriteInt16(input, unionOffset, unchecked((short)strokes[index].Key));
                Marshal.WriteInt32(input, unionOffset + 4, strokes[index].KeyUp ? 2 : 0); // KEYEVENTF_KEYUP
            }

            sent = SendInput((uint)strokes.Length, buffer, inputSize);
            error = Marshal.GetLastWin32Error();
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }

        if (sent != strokes.Length)
            throw new InvalidOperationException($"Windows could not inject the keyboard shortcut (Win32 error {error}, INPUT size {inputSize}).");
    }

    private enum VirtualKey : ushort { Control = 0x11, V = 0x56, Z = 0x5A, Return = 0x0D }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint inputCount, IntPtr inputs, int inputSize);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetForegroundWindow(nint window);
}
