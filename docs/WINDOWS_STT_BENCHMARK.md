# Windows STT benchmark

Date: 2026-08-18. Runtime: Windows x64 CPU, Sherpa-ONNX NuGet 1.13.5, SenseVoice INT8 model `sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09`, Silero VAD enabled, one process per probe invocation. Latency includes recognizer construction; the production service keeps the recognizer warm.

## Official Cantonese clips

The first four official clips have ground truths published by Sherpa-ONNX. The probe output matched each ground truth exactly after Unicode normalization, giving CER 0 on this small set.

| Sample | Audio | Sherpa output | STT ms | RTF | CER |
|---|---:|---|---:|---:|---:|
| yue-0.wav | 3.072 s | 两只小企鹅都有嘢食 | 2782 | 0.906 | 0.000 |
| yue-1.wav | 15.104 s | 叫做诶诶直入式你个脑部里边咧记得呢一个嘅以前香港有一个广告好出名嘅佢乜嘢都冇噶净系影住喺弥敦道佢哋间铺头嘅啫但系就不停有人嗌啦平平吧平吧 | 5272 | 0.349 | 0.000 |
| yue-2.wav | 4.608 s | 忽然从光线死角嘅阴影度窜出一只大猫 | 3611 | 0.784 | 0.000 |
| yue-3.wav | 4.352 s | 今日我带大家去见识一位九零后嘅靓仔咧 | 3712 | 0.853 | 0.000 |

## User failure WAV

File: `%LOCALAPPDATA%\VoiceWritingAssistant\recordings\recording-20260818-131910-465994fb1817403ebd901c4903a0a2bc.wav` (7.588 s). There is no human reference transcript, so CER is intentionally not claimed.

| Provider | Model/language | STT ms | RTF | Raw output |
|---|---|---:|---:|---|
| whisper.cpp | ggml-base.bin / `zh` | 4345 | 0.572 | 開始了 我講的 現在是有跳動的 / 但我不知道 它原來只有Stop會怎樣 |
| Sherpa-ONNX | SenseVoice INT8 / auto + Silero VAD | 3963 | 0.522 | 開始啦我講嘢 诶而家系有跳動嘅 但系我唔知道佢完咗之后 STOP 会点啦 |

This is evidence that the Cantonese-specialised provider no longer turns this clip into an unrelated English transcript. It is not a claim that one user clip proves universal accuracy.
