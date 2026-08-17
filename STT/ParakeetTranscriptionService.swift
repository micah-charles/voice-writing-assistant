import Foundation
#if canImport(FluidAudio)
import FluidAudio
#endif

private actor ParakeetRuntime {
    static let shared = ParakeetRuntime()
    #if canImport(FluidAudio)
    private var manager: AsrManager?
    private func instance() async throws -> AsrManager {
        if let manager { return manager }
        let models = try await AsrModels.downloadAndLoad(version: .v3)
        let loaded = AsrManager(models: models)
        manager = loaded
        return loaded
    }
    func warm() async throws { _ = try await instance() }
    func transcribe(_ url: URL) async throws -> ASRResult {
        let manager = try await instance()
        var state = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
        return try await manager.transcribe(url, decoderState: &state)
    }
    #endif
}

struct ParakeetTranscriptionService: SpeechToTextService {
    let providerName = "Parakeet"
    func readiness() async -> ProviderReadiness {
        #if canImport(FluidAudio)
        return ProviderReadiness(ready: true, detail: "Embedded FluidAudio Parakeet v3 available")
        #else
        return ProviderReadiness(ready: false, detail: "FluidAudio package is not linked")
        #endif
    }
    func warm() async throws {
        #if canImport(FluidAudio)
        try await ParakeetRuntime.shared.warm()
        #else
        throw SpeechToTextError.unavailable(providerName)
        #endif
    }
    func transcribe(audioURL: URL, language: RecognitionLanguage, vocabularyHints: [String]) async throws -> TranscriptResult {
        #if canImport(FluidAudio)
        let result = try await ParakeetRuntime.shared.transcribe(audioURL)
        return TranscriptResult(text: result.text, language: language.whisperLanguageCode, duration: result.duration, confidence: Double(result.confidence), provider: providerName)
        #else
        throw SpeechToTextError.unavailable(providerName)
        #endif
    }
}
