using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows;
using System.Windows.Automation;
using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public sealed class ForegroundContextCaptureService(AppSettings settings) : IContextCaptureService
{
    public Task<CapturedContext> CaptureAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var window = GetForegroundWindow();
        if (window == 0)
            return Task.FromResult(new CapturedContext());

        var titleLength = GetWindowTextLength(window);
        var title = new StringBuilder(titleLength + 1);
        _ = GetWindowText(window, title, title.Capacity);
        _ = GetWindowThreadProcessId(window, out var processId);

        string? processName = null;
        string? executableName = null;
        try
        {
            using var process = Process.GetProcessById((int)processId);
            processName = process.MainModule?.FileVersionInfo.FileDescription ?? process.ProcessName;
            executableName = process.MainModule?.ModuleName ?? process.ProcessName + ".exe";
        }
        catch
        {
            // Protected/system windows may deny process metadata; title and HWND remain useful.
        }

        var selectedText = settings.UseSelectedTextContext ? TryCaptureSelectedText(window) : null;
        var clipboardText = settings.UseClipboardContext ? TryGetClipboardText() : null;
        var raw = new CapturedContext
        {
            ActiveApplicationName = processName,
            ExecutableName = executableName,
            WindowTitle = title.ToString(),
            SelectedText = selectedText,
            ClipboardText = clipboardText,
            BrowserUrl = settings.UseBrowserUrl ? TryGetBrowserUrl(window, executableName) : null,
            PlatformTargetId = window.ToString("X")
        };
        return Task.FromResult(new ContextPrivacyPolicy().Filter(raw, settings));
    }

    private static string? TryCaptureSelectedText(nint window)
    {
        try
        {
            var focused = AutomationElement.FocusedElement;
            if (focused is not null && focused.TryGetCurrentPattern(TextPattern.Pattern, out var pattern))
            {
                var selected = ((TextPattern)pattern).GetSelection();
                var value = string.Concat(selected.Select(range => range.GetText(100_000)));
                if (!string.IsNullOrWhiteSpace(value)) return value;
            }
        }
        catch { }

        IDataObject? previous = null;
        try
        {
            previous = Clipboard.GetDataObject();
            var marker = $"VoiceWritingAssistant:{Guid.NewGuid():N}";
            Clipboard.SetText(marker);
            SendCopyChord();
            Thread.Sleep(90);
            var value = Clipboard.ContainsText() ? Clipboard.GetText() : null;
            return value == marker ? null : value;
        }
        catch { return null; }
        finally
        {
            if (previous is not null)
            {
                try { Clipboard.SetDataObject(previous, true); } catch { }
            }
        }
    }

    private static string? TryGetBrowserUrl(nint window, string? executableName)
    {
        var executable = executableName?.ToLowerInvariant();
        if (executable is not ("chrome.exe" or "msedge.exe" or "firefox.exe" or "brave.exe" or "opera.exe")) return null;
        try
        {
            var root = AutomationElement.FromHandle(window);
            var edits = root.FindAll(TreeScope.Descendants, new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Edit));
            foreach (AutomationElement edit in edits)
            {
                var name = edit.Current.Name;
                var automationId = edit.Current.AutomationId;
                var looksLikeAddress = name.Contains("address", StringComparison.OrdinalIgnoreCase)
                    || name.Contains("search bar", StringComparison.OrdinalIgnoreCase)
                    || automationId.Contains("address", StringComparison.OrdinalIgnoreCase)
                    || automationId.Contains("urlbar", StringComparison.OrdinalIgnoreCase);
                if (!looksLikeAddress || !edit.TryGetCurrentPattern(ValuePattern.Pattern, out var pattern)) continue;
                var value = ((ValuePattern)pattern).Current.Value;
                if (Uri.TryCreate(value, UriKind.Absolute, out var uri) && uri.Scheme is "http" or "https") return uri.AbsoluteUri;
            }
        }
        catch { }
        return null;
    }

    private static string? TryGetClipboardText()
    {
        try { return Clipboard.ContainsText() ? Clipboard.GetText() : null; }
        catch { return null; }
    }

    private static void SendCopyChord()
    {
        var inputs = new[] { Key(0x11, false), Key(0x43, false), Key(0x43, true), Key(0x11, true) };
        _ = SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Input>());
    }

    private static Input Key(ushort key, bool up) => new() { Type = 1, Union = new InputUnion { Keyboard = new KeyboardInput { VirtualKey = key, Flags = up ? 2u : 0u } } };

    [StructLayout(LayoutKind.Sequential)] private struct Input { public uint Type; public InputUnion Union; }
    [StructLayout(LayoutKind.Explicit)] private struct InputUnion { [FieldOffset(0)] public KeyboardInput Keyboard; }
    [StructLayout(LayoutKind.Sequential)] private struct KeyboardInput { public ushort VirtualKey; public ushort ScanCode; public uint Flags; public uint Time; public nuint ExtraInfo; }

    [DllImport("user32.dll")]
    private static extern nint GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint GetWindowThreadProcessId(nint window, out uint processId);

    [DllImport("user32.dll", EntryPoint = "GetWindowTextLengthW", SetLastError = true)]
    private static extern int GetWindowTextLength(nint window);

    [DllImport("user32.dll", EntryPoint = "GetWindowTextW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int GetWindowText(nint window, StringBuilder text, int maximumCount);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint inputCount, [In] Input[] inputs, int inputSize);
}
