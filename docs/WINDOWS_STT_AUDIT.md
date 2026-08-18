# Windows STT audit

Before the Sherpa work, Windows used a single `whisper-cli.exe` process with a `ggml-base.bin` model. Cantonese was passed as Whisper language `yue`; with the bundled base model this produced English on the supplied Cantonese WAV. The recording path is WASAPI/NAudio and writes mono 16 kHz PCM WAV files.

The macOS implementation is separate and unchanged. It routes Chinese to WhisperKit (normally the `small` model) and English may use Parakeet, so it has both a larger model and a different provider stack.

The Windows implementation now has a provider boundary and deterministic router. Automatic prefers Sherpa SenseVoice for Chinese only when the verified model, tokens, and VAD files are present; otherwise it uses Whisper.cpp. Technical Sherpa failures are eligible for Whisper fallback, while cancellation is propagated.
