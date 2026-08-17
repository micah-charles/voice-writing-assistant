# macOS configuration rules

This document is mandatory for contributors and coding agents configuring, building, or testing the macOS app.

## Local development setup

1. Install Xcode and open `VoiceWritingAssistant.xcodeproj` once so Swift Package Manager can resolve dependencies.
2. Run the `VoiceWritingAssistant` scheme on **My Mac**.
3. Grant **Microphone** permission when macOS asks.
4. Grant **Accessibility** permission in System Settings → Privacy & Security → Accessibility. Use the exact current `.app` bundle; remove obsolete entries after changing its signing identity.
5. If using Codex, install the `codex` executable, sign in with `codex login`, and verify `codex login status`.
6. If using Ollama, start the local service and select an installed model, for example `qwen3:8b`.

## Signing rule

- For stable local Accessibility permission, build with a persistent **Apple Development** signing certificate.
- Do not distribute an ad-hoc-signed build as the normal test app: each changed ad-hoc identity can cause macOS to deny Accessibility again.
- Keep the bundle identifier stable unless deliberately migrating settings and permissions.

## Codex rule

- Finder-launched macOS apps commonly start with `/` as their working directory.
- Codex CLI must include `--skip-git-repo-check` for these invocations; otherwise it rejects the non-git working directory.
- Use `--sandbox read-only`; never put API keys, ChatGPT credentials, browser cookies, or personal history into source control.
- In the app, `Codex CLI` means Codex only. `Automatic fallback` may race Codex and Ollama; `Ollama (local)` means Ollama only.

## UI rule

- Settings, History, and Dictionary windows must activate the app and order themselves in front of the active app. Do not leave auxiliary windows behind the dictation target.

## Repository rule

- Commit source, tests, docs, Xcode project metadata, and `Package.resolved`.
- Never commit `.app` packages, `dist/`, recordings, local history/settings, `xcuserdata`, `.env` files, or machine-specific paths.
