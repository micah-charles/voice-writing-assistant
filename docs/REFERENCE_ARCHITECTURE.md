# Reference architecture research

Research completed 2026-08-17. This document records architectural lessons only. ZeroTypeLocal does not copy source code from the projects below.

| Project | Useful feature / architecture | License | Reuse decision |
| --- | --- | --- | --- |
| [MacParakeet](https://github.com/moona3k/macparakeet) | Native Swift/SwiftUI local-first application; explicit STT routing and scheduler; Parakeet for the English path and WhisperKit for CJK; deterministic vocabulary cleanup before paste. | GPL-3.0 | No source reuse. GPL is incompatible with keeping this independently licensed implementation proprietary/permissive. Copy the concepts of a protocol boundary, explicit scheduler, and privacy split. |
| [VoiceInk](https://github.com/Beingpax/VoiceInk) | Mature native macOS ergonomics: hotkeys, local transcription, selected-text support, vocabulary, and fallback-oriented settings. Uses whisper.cpp and FluidAudio. | GPL-3.0 | No source reuse. Independently implement small, native services and verify all future package licenses. |
| [Astra](https://github.com/amateur-dev/Astra) | Local-first global-hotkey flow, explicit microphone/accessibility onboarding, local model download and optional Ollama polish. | MIT | Conceptual reference only. Its Electron/Node architecture conflicts with the native-Swift v1 requirement, so no code will be reused. |
| WhisperDictation | The name identifies several projects rather than one authoritative repository. The stable conceptual lesson is model download/warm-up plus a clear recording-to-transcription lifecycle. | Verify exact repository before use | No code reuse until an exact repository and license are identified. |
| `doggy8088/macparakeet` | The named URL could not be fetched during research, so its identity and licence are unverified. | Unverified | Do not copy. The separate `moona3k/macparakeet` research supplies the relevant routing concepts. |
| `doggy8088/voice-memos-2` | The named URL could not be fetched during research, so its identity and licence are unverified. | Unverified | No source reuse. |
| `doggy8088/opencc-swift` | The named URL could not be fetched during research, so a Swift wrapper and its conversion data are unverified. | Unverified | Phase 8 will choose only a pinned, licence-reviewed implementation. Never convert English tokens wholesale. |
| `doggy8088/opencc-rust` | The named URL could not be fetched during research. | Unverified | Not selected for v1 because an FFI/Rust toolchain increases release risk. |
| [doggy8088/dgx-faster-whisper](https://github.com/doggy8088/dgx-faster-whisper) | A Dockerised CUDA faster-whisper CLI and OpenAI-compatible HTTP service for Linux/DGX. | No LICENSE file observed in repository root | No source reuse; it conflicts with the native, in-process macOS/no-Python-server design. |
| `codex-asr` | No authoritative repository URL was supplied and the likely named URL could not be fetched. | Unverified | Not selected. The product will never make an unofficial authenticated-Codex route an STT dependency; any later integration must be opt-in, isolated, timeout-bound, and clearly labelled experimental. |

## Adopted architecture

`Global shortcut → AVFoundation recorder → explicit DictationState → (Phase 2 local STT) → (later minimal context capture) → (later provider router) → terminology normalization → clipboard / accessibility paste`

The Phase 1 target deliberately has no network dependency, model package, API key, Python service, history store, or text processor. This preserves the local trust boundary while stabilising the app lifecycle and permissions.

## Source notes

MacParakeet documents local on-device STT, its Parakeet/WhisperKit route, and a shared runtime/scheduler in its [README](https://github.com/moona3k/macparakeet) and [audio pipeline specification](https://github.com/moona3k/macparakeet/blob/main/spec/05-audio-pipeline.md). VoiceInk documents its native macOS dependencies and GPL-3.0 license in its [README](https://github.com/Beingpax/VoiceInk). Astra documents local microphone/accessibility onboarding, model download, Ollama option, and MIT license in its [README](https://github.com/amateur-dev/Astra). Facts are recorded as of the research date; pin a commit and re-check licences before importing a library.
