import Foundation
#if canImport(WhisperKit)
import WhisperKit
#endif

/// In-process local transcription. The model is downloaded by WhisperKit on its first configured use.
private actor WhisperKitRuntime {
    static let shared = WhisperKitRuntime()
    #if canImport(WhisperKit)
    private var kit: WhisperKit?
    private var loadedModel: String?
    private func instance(for model: String) async throws -> WhisperKit {
        if let kit, loadedModel == model { return kit }
        let loaded = try await WhisperKit(model: model, prewarm: true)
        kit = loaded; loadedModel = model
        return loaded
    }
    func warm(model: String) async throws { _ = try await instance(for: model) }
    func transcribe(audioURL: URL, model: String, language: String?) async throws -> String {
        // WhisperKit defaults an unspecified language to English. Explicitly ask it to
        // detect a language for Auto/Mixed, or use the user's selected Cantonese code.
        let options = DecodingOptions(task: .transcribe, language: language, detectLanguage: language == nil)
        let batches = await (try await instance(for: model)).transcribe(audioPaths: [audioURL.path], decodeOptions: options)
        return (batches.first ?? nil)?.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    #endif
}

struct WhisperKitTranscriptionService: SpeechToTextService {
    let model: String
    let providerName = "WhisperKit"
    init(model: String = "small") { self.model = model }
    func readiness() async -> ProviderReadiness {
        #if canImport(WhisperKit)
        return ProviderReadiness(ready: true, detail: "Embedded WhisperKit available")
        #else
        return ProviderReadiness(ready: false, detail: "WhisperKit package is not linked")
        #endif
    }
    func warm() async throws {
        #if canImport(WhisperKit)
        try await WhisperKitRuntime.shared.warm(model: model)
        #else
        throw SpeechToTextError.unavailable(providerName)
        #endif
    }
    func transcribe(audioURL: URL, language: RecognitionLanguage, vocabularyHints: [String]) async throws -> TranscriptResult {
        #if canImport(WhisperKit)
        let text = try await WhisperKitRuntime.shared.transcribe(audioURL: audioURL, model: model, language: language.whisperLanguageCode)
        return TranscriptResult(text: text, language: language.whisperLanguageCode, duration: nil, confidence: nil, provider: providerName)
        #else
        throw SpeechToTextError.unavailable(providerName)
        #endif
    }
}
