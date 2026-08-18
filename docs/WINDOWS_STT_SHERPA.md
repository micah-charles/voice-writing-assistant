# Windows Sherpa-ONNX STT

The Windows provider is `SherpaOnnxTranscriptionService` in the Infrastructure project. It uses the official `org.k2fsa.sherpa.onnx` NuGet package 1.13.5, SenseVoice Cantonese model files, and Silero VAD. Audio is validated as mono, 16 kHz, 16-bit PCM before decoding. VAD uses 512-sample windows, 0.3 threshold, 250 ms minimum speech and 500 ms minimum silence; clause pauses are retained by decoding each detected segment.

The NuGet package is Apache-2.0 licensed. The official SenseVoice model is the INT8 Cantonese-capable artifact; its verified `model.int8.onnx` file is 237,115,547 bytes on this machine (the official listing rounds it to 226 MB), with `tokens.txt` and the official test WAV corpus. Silero VAD is the official `silero_vad.onnx` release artifact.

The official model archive is:

`https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09.tar.bz2`

The VAD model is:

`https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx`

The app stores these under `%LOCALAPPDATA%\VoiceWritingAssistant\models`. The model is local-only and the SenseVoice model output has no punctuation; the existing text-cleanup stage can add punctuation.

## Validation status

The official archive and VAD were downloaded and the Windows solution compiles with the Sherpa dependency. An initial probe appeared to crash because a slow `tar` extraction had left a 39 MB truncated model. Re-extracting with Python `tarfile` produced the complete 237,115,547-byte model. An isolated probe then transcribed the real user WAV successfully in Cantonese:

`開始啦我講嘢 诶而家系有跳動嘅 但系我唔知道佢完咗之后 STOP 会点啦`

The provider therefore validates a minimum model size before loading, and the model manager verifies required files before marking an installation usable. Partial downloads remain unavailable and automatically fall back to Whisper.
