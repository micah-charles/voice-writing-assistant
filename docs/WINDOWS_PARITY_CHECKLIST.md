# Windows feature parity checklist

The macOS app is the behavioral contract. Platform-specific implementations may differ, but the Windows app must expose the same user-facing capabilities and local privacy guarantees.

## Application shell

- [x] Tray menu with current state, start, stop, cancel, selected-text transform, History, Dictionary, Settings, and Exit.
- [x] Floating record control that can be hidden and exposes quick settings.
- [x] Recorder/review surface with elapsed time, level, processed text, Paste, Use Raw, and Cancel.
- [x] Windows opened from the tray reliably activate and come to the foreground.

## Settings

- [x] Push-to-talk and toggle shortcut modes.
- [x] Auto-paste, clipboard restoration, review-before-paste, floating-control visibility, and model warm-up.
- [x] Speech provider, recognition language, and local Whisper model configuration.
- [x] Text processor, writing style, Codex/Ollama configuration, and timeout.
- [x] Active-app, window-title, selected-text, clipboard, browser-URL, and local-history privacy controls.
- [x] Output language and Chinese conversion controls.
- [x] Permission/readiness diagnostics.

## Dictation workflows

- [x] Regular dictation through transcription, contextual cleanup, normalization, optional review, and delivery.
- [x] Selected-text transformation using a separate shortcut and spoken instruction.
- [x] Cancellation from the keyboard and UI.
- [x] App profiles and safe auto-send behavior.
- [x] Provider fallback and alternate result capture.

## Local data

- [x] Atomic settings persistence with migration of existing Windows settings.
- [x] Optional local history containing transcript, final text, provider, mode, app, latency, and alternatives; never audio.
- [x] History detail, copy/reuse actions, and clear-history control.
- [x] Personal dictionary persistence with preferred forms, aliases, and categories.
- [x] Dictionary hints supplied to transcription where supported and normalization applied to results.

## Verification

- [x] Unit tests cover settings migration, history, dictionary, terminology, privacy filtering, review, transform, shortcut routing, alternate replacement, and native paste/clipboard restoration (20 passing tests).
- [x] Release build has no warnings or errors.
- [x] Windows runtime checks cover microphone capture, real global-shortcut recording/cancellation, selected-text clipboard fallback, target focus and paste, clipboard restoration, foreground auxiliary windows, and review UI behavior.
