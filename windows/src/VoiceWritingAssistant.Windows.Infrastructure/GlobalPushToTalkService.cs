using System.Diagnostics;
using System.Runtime.InteropServices;
using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public sealed class GlobalPushToTalkService : IDisposable
{
    private const int KeyboardHook = 13;
    private const int KeyDown = 0x0100;
    private const int KeyUp = 0x0101;
    private const int SystemKeyDown = 0x0104;
    private const int SystemKeyUp = 0x0105;
    private const int VirtualKeyControl = 0x11;
    private const int VirtualKeyAlt = 0x12;
    private readonly HookProcedure _callback;
    private nint _hook;
    private readonly GlobalShortcutStateMachine _state = new();

    public ShortcutMode Mode { get; set; } = ShortcutMode.PushToTalk;

    public GlobalPushToTalkService()
    {
        _callback = HandleHook;
        using var process = Process.GetCurrentProcess();
        using var module = process.MainModule;
        _hook = SetWindowsHookEx(KeyboardHook, _callback, GetModuleHandle(module?.ModuleName), 0);
        if (_hook == 0)
            throw new InvalidOperationException("Windows could not install the Control+R keyboard hook.");
    }

    public event EventHandler? Pressed;
    public event EventHandler? Released;
    public event EventHandler? TransformPressed;
    public event EventHandler? TransformReleased;
    public event EventHandler? CancelPressed;

    private nint HandleHook(int code, nint message, nint data)
    {
        if (code >= 0)
        {
            var key = Marshal.ReadInt32(data);
            var isDown = message == KeyDown || message == SystemKeyDown;
            var isUp = message == KeyUp || message == SystemKeyUp;
            var controlDown = (GetAsyncKeyState(VirtualKeyControl) & 0x8000) != 0;
            var altDown = (GetAsyncKeyState(VirtualKeyAlt) & 0x8000) != 0;
            var action = _state.Handle(key, isDown, isUp, controlDown, altDown, Mode);
            switch (action)
            {
                case GlobalShortcutAction.StartDictation: Pressed?.Invoke(this, EventArgs.Empty); break;
                case GlobalShortcutAction.StopDictation: Released?.Invoke(this, EventArgs.Empty); break;
                case GlobalShortcutAction.StartTransform: TransformPressed?.Invoke(this, EventArgs.Empty); break;
                case GlobalShortcutAction.StopTransform: TransformReleased?.Invoke(this, EventArgs.Empty); break;
                case GlobalShortcutAction.Cancel: CancelPressed?.Invoke(this, EventArgs.Empty); break;
            }
            if (action != GlobalShortcutAction.None) return 1;
        }
        return CallNextHookEx(_hook, code, message, data);
    }

    public void Dispose()
    {
        if (_hook != 0)
            _ = UnhookWindowsHookEx(_hook);
        _hook = 0;
        GC.SuppressFinalize(this);
    }

    private delegate nint HookProcedure(int code, nint message, nint data);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern nint SetWindowsHookEx(int hookId, HookProcedure callback, nint module, uint threadId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(nint hook);

    [DllImport("user32.dll")]
    private static extern nint CallNextHookEx(nint hook, int code, nint message, nint data);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int key);

    [DllImport("kernel32.dll", EntryPoint = "GetModuleHandleW", CharSet = CharSet.Unicode)]
    private static extern nint GetModuleHandle(string? moduleName);
}
