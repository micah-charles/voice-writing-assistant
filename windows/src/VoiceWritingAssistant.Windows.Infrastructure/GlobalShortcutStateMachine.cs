using VoiceWritingAssistant.Core;

namespace VoiceWritingAssistant.Windows.Infrastructure;

public enum GlobalShortcutAction { None, Suppress, StartDictation, StopDictation, StartTransform, StopTransform, Cancel }

public sealed class GlobalShortcutStateMachine
{
    private const int R = 0x52;
    private const int E = 0x45;
    private const int Escape = 0x1B;
    private bool _rDown;
    private bool _eDown;
    private bool _active;

    public GlobalShortcutAction Handle(int key, bool isDown, bool isUp, bool controlDown, bool altDown, ShortcutMode mode)
    {
        if (key == Escape && isDown && _active)
        {
            _active = false;
            return GlobalShortcutAction.Cancel;
        }
        if (key == E && ((controlDown && altDown) || (isUp && _eDown)))
        {
            if (isDown && !_eDown) { _eDown = true; _active = true; return GlobalShortcutAction.StartTransform; }
            if (isUp && _eDown) { _eDown = false; _active = false; return GlobalShortcutAction.StopTransform; }
            return GlobalShortcutAction.Suppress;
        }
        if (key == R && (controlDown || (isUp && _rDown)))
        {
            if (isDown && !_rDown)
            {
                _rDown = true;
                if (mode == ShortcutMode.Toggle && _active) { _active = false; return GlobalShortcutAction.StopDictation; }
                _active = true; return GlobalShortcutAction.StartDictation;
            }
            if (isUp && _rDown)
            {
                _rDown = false;
                if (mode == ShortcutMode.PushToTalk) { _active = false; return GlobalShortcutAction.StopDictation; }
            }
            return GlobalShortcutAction.Suppress;
        }
        return GlobalShortcutAction.None;
    }
}
