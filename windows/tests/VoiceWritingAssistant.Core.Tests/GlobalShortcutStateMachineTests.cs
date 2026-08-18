using VoiceWritingAssistant.Core;
using VoiceWritingAssistant.Windows.Infrastructure;

namespace VoiceWritingAssistant.Core.Tests;

public sealed class GlobalShortcutStateMachineTests
{
    [Fact]
    public void PushToTalkStartsAndStopsOnKeyEdges()
    {
        var state = new GlobalShortcutStateMachine();
        Assert.Equal(GlobalShortcutAction.StartDictation, state.Handle(0x52, true, false, true, false, ShortcutMode.PushToTalk));
        Assert.Equal(GlobalShortcutAction.Suppress, state.Handle(0x52, true, false, true, false, ShortcutMode.PushToTalk));
        Assert.Equal(GlobalShortcutAction.StopDictation, state.Handle(0x52, false, true, false, false, ShortcutMode.PushToTalk));
    }

    [Fact]
    public void ToggleStopsOnSecondPressAndEscapeCancels()
    {
        var state = new GlobalShortcutStateMachine();
        Assert.Equal(GlobalShortcutAction.StartDictation, state.Handle(0x52, true, false, true, false, ShortcutMode.Toggle));
        Assert.Equal(GlobalShortcutAction.Suppress, state.Handle(0x52, false, true, false, false, ShortcutMode.Toggle));
        Assert.Equal(GlobalShortcutAction.Cancel, state.Handle(0x1B, true, false, false, false, ShortcutMode.Toggle));
        Assert.Equal(GlobalShortcutAction.StartDictation, state.Handle(0x52, true, false, true, false, ShortcutMode.Toggle));
        state.Handle(0x52, false, true, false, false, ShortcutMode.Toggle);
        Assert.Equal(GlobalShortcutAction.StopDictation, state.Handle(0x52, true, false, true, false, ShortcutMode.Toggle));
    }

    [Fact]
    public void TransformUsesIndependentControlAltEChord()
    {
        var state = new GlobalShortcutStateMachine();
        Assert.Equal(GlobalShortcutAction.StartTransform, state.Handle(0x45, true, false, true, true, ShortcutMode.PushToTalk));
        Assert.Equal(GlobalShortcutAction.StopTransform, state.Handle(0x45, false, true, false, false, ShortcutMode.PushToTalk));
    }
}
