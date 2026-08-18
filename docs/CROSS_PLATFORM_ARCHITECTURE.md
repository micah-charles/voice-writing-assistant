# Cross-platform architecture

The product is implemented as native shells around common product semantics. macOS remains Swift/AppKit/SwiftUI; Windows uses C#/.NET/WPF and Win32. UI, permissions, audio capture, foreground-window access, global shortcuts, text selection and paste injection remain platform-specific.

## What is shared

`shared/` is the source of truth for serialised behavior that both native apps can consume:

- application-profile schema and defaults;
- app modes, processing styles and output-language identifiers;
- safe defaults such as `autoSend: false`.

The portable C# project in `windows/src/VoiceWritingAssistant.Core` owns orchestration and pure logic: state transitions, profile matching, mode classification, prompt construction, output sanitising, processor fallback and the recording-to-paste workflow. The equivalent Swift types should migrate to loading the same `shared/` documents in a later refactor. Golden contract tests should be added on both platforms before changing a shared identifier.

## What stays native

| Capability | macOS | Windows |
| --- | --- | --- |
| UI | SwiftUI/AppKit | WPF (Fluent styling can be layered later) |
| Audio | AVFoundation | WASAPI via NAudio |
| Shortcut | Carbon hot key | low-level keyboard hook / Win32 |
| Active app | NSWorkspace | `GetForegroundWindow` / process APIs |
| Selected text | Accessibility AX | UI Automation `TextPattern` |
| Paste | AX + Command-V | UI Automation + `SendInput` Ctrl-V |
| Local STT | WhisperKit/Parakeet/whisper.cpp | whisper.cpp initially; provider seam supports faster-whisper later |

## Dependency direction

```text
WPF shell -> Windows adapters -> Core contracts
    |                              ^
    +------------------------------+

shared JSON -> Windows Core now
shared JSON -> macOS core after compatibility tests are added
```

The core never references WPF, Win32, NAudio, a concrete STT engine or a concrete AI processor. Providers implement small ports and can be replaced independently.

## First Windows vertical slice

The initial slice supports `Control+R` push-to-talk and the floating R control. It records through WASAPI, transcribes through an installed `whisper-cli`, captures the original foreground application, applies the shared application profile, tries Codex CLI then Ollama then deterministic cleanup, and pastes with clipboard restoration. Configuration is read from `%LOCALAPPDATA%\\VoiceWritingAssistant\\settings.json`.

The app deliberately does not auto-send. Selected-text transformation, UI Automation insertion, model management, continuous mode, VAD and voice commands remain later adapters/features; they do not require changes to the workflow boundary.
