# Voice Writing Assistant for Windows

This is the native Windows application. It is a WPF application on .NET 10 LTS with a portable application core and Windows adapters for WASAPI, UI Automation/Win32 context capture, global shortcuts and paste injection.

## Prerequisites

1. Install the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0).
2. Install `whisper-cli` from [whisper.cpp](https://github.com/ggml-org/whisper.cpp) and put it on `PATH` (or set `whisperExecutable` to its full path).
3. Download a compatible whisper.cpp model and set `whisperModelPath` in `%LOCALAPPDATA%\VoiceWritingAssistant\settings.json` (this remains the reliable fallback).
4. Optionally install/sign in to Codex CLI, or run Ollama and set `ollamaModel`. If neither is available, deterministic cleanup is used.

Build and run from the repository root:

```powershell
dotnet build .\windows\VoiceWritingAssistant.Windows.sln
dotnet run --project .\windows\src\VoiceWritingAssistant.Windows.App
```

The settings file is created on first launch. In Settings → Speech recognition, choose `Automatic` and click `Download Cantonese SenseVoice model` to install the official local SenseVoice INT8 model plus Silero VAD. Automatic uses Sherpa-ONNX for Cantonese/Chinese/mixed speech and falls back to Whisper.cpp if the model is missing or a technical runtime failure occurs. Hold `Control+R` to record and release it to transcribe, process and paste. Toggle mode is available in Settings. Select text and hold `Control+Alt+E` to speak a transformation instruction. Press Escape to cancel. The floating R also supports mouse-down/mouse-up recording and right-click quick settings.

If multiple Codex installations exist, set `codexExecutable` to the full path of the working CLI executable. This avoids Windows selecting an inaccessible Microsoft Store package ahead of a standalone npm installation.

## Current behavior

- Captures the target window before recording so the floating UI cannot steal the paste destination.
- Records a temporary WAV through WASAPI and deletes it after transcription.
- Applies the shared app profile from `shared/default-app-profiles.json`.
- Tries the configured text processor, with Codex CLI → Ollama → rules as the automatic fallback chain.
- Restores the previous clipboard after automatic paste when `restoreClipboard` is enabled.
- Keeps auto-send disabled in all supplied profiles.
- Provides foreground Settings, History, Personal Dictionary, review, recorder, and quick-settings windows from the tray or floating control.
- Stores enabled local text history and supports clearing it at any time; audio is not retained unless the optional WAV archive is enabled.
- Optionally archives the last 10 WAV recordings under `%LOCALAPPDATA%\VoiceWritingAssistant\recordings` for transcription quality review; the History window can open or clear them.
- Captures selected text and supported browser address fields only when their privacy toggles are enabled.
- Races Codex and Ollama in Automatic mode, records alternate results, and can undo and replace the last paste with an alternative.
- Respects an explicit processor choice: `codexCLI` uses Codex only, `ollama` uses Ollama only, and only `automatic` enables provider fallback.
- Applies personal-dictionary hints to whisper.cpp and full OpenCC Traditional/Taiwan conversion locally.
- Shows the actual STT provider, model, language, VAD state, timing, and fallback metadata in saved history entries.

## Platform notes

- whisper.cpp and model download remain explicit local prerequisites.
- Paste uses the clipboard and `SendInput`; selected-text and browser URL reads use UI Automation with a clipboard-preserving fallback for controls that do not expose selection.
- Browser URL capture supports Chrome, Edge, Firefox, Brave, and Opera address controls that expose a URL through UI Automation.
- Windows provides whisper.cpp rather than the Apple-only WhisperKit and FluidAudio engines.

See [the cross-platform architecture](../docs/CROSS_PLATFORM_ARCHITECTURE.md) for the shared/native boundary and extension points.
