# Voice Writing Assistant

Voice Writing Assistant is a native, local-first macOS voice-writing assistant. Hold a global shortcut, dictate, and it transcribes locally, captures only the enabled context, cleans text with Codex CLI/Ollama/rules, normalises terminology, and pastes into the prior app. No OpenAI API key or background Python server is used.

## Features

- Hold `Control + R` to dictate; release **R** to stop and paste back into the app that had the cursor. In Toggle mode, press `Control + R` once to start and once again to stop.
- Hold `Control + Option + E` after selecting text to speak a transformation instruction.
- Local STT router: embedded [WhisperKit](https://github.com/argmaxinc/argmax-oss-swift), Parakeet seam, then local `whisper-cli` fallback. Auto mode chooses Parakeet first for English and WhisperKit first for Chinese/Cantonese/mixed input.
- Deterministic app-mode classification for mail, chat, technical editors, documents, and notes.
- Text processing priority: Codex CLI (existing authentication), local Ollama `/api/chat`, then safe rule-only cleanup.
- Personal dictionary terminology correction and conservative Traditional Chinese conversion.
- Review-before-paste, clipboard restore, accessibility paste, optional local history, and explicit context/privacy settings.

## Build and run

Open [VoiceWritingAssistant.xcodeproj](VoiceWritingAssistant.xcodeproj) in Xcode. Swift Package Manager resolves WhisperKit from `argmax-oss-swift`; on first transcription WhisperKit downloads the selected local model. Run the `VoiceWritingAssistant` scheme and grant Microphone permission. Grant Accessibility permission for automatic paste and selected-text capture. See [macOS configuration rules](docs/MACOS_CONFIGURATION.md) before building or signing a local package.

```sh
xcodebuild -project VoiceWritingAssistant.xcodeproj -scheme VoiceWritingAssistant -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

## Providers

WhisperKit runs on-device. Its models are local after download and the selected model is retained and warmed across dictations. Parakeet v3 is embedded via FluidAudio, used first for English in Automatic mode, and retains a warmed local model. `whisper-cli` is supported when whisper.cpp is installed and on `PATH`.

Codex uses only the existing `codex` executable and invokes `codex exec --ephemeral --skip-git-repo-check --sandbox read-only` with closed stdin. It uses the configured processing timeout and does not read tokens, cookies, or credential files. Codex processing may use the user's Codex/ChatGPT service and is therefore not fully offline.

Ollama uses only the configured endpoint (default `http://127.0.0.1:11434`) and its local `/api/chat` endpoint. Enter a locally installed model in Settings.

## Privacy

Audio stays in a temporary local `.caf` file and is removed on cancellation. Clipboard context and browser URL are off by default. When enabled, browser context requests only the visible URL from Safari, Chrome, or Edge through macOS Automation; it never reads page content or cookies. History is off by default and stores only text metadata locally when explicitly enabled; audio is not retained. The app sends only enabled context fields to the selected processor. It never stores API keys, Codex credentials, or browser cookies.

## Troubleshooting

- **“WhisperKit unavailable”**: open the project in Xcode once so SwiftPM can resolve the package; ensure network access for the one-time model download.
- **No automatic paste**: enable the app in System Settings → Privacy & Security → Accessibility. The result remains on the clipboard when permission is missing.
- **Codex failure**: run `codex --version`; the app falls back to Ollama, then rule-only cleanup.
- **Ollama failure**: start Ollama and set a valid local model. The app does not wait indefinitely; it falls back.
- **Selected text unavailable**: the source control may not expose `AXSelectedText`; select a native editable control and confirm Accessibility permission.

## Known limitations

Browser URL capture depends on the browser granting macOS Automation access and is unavailable for unsupported browsers. The built-in Chinese fallback is intentionally conservative; Phase 8 should replace it with a licence-reviewed OpenCC package for full conversion coverage. Full Xcode build verification currently requires repairing this machine's Xcode plug-in installation (`IDESimulatorFoundation` cannot load because of a `DVTDownloads` mismatch); source type-checking passes.
