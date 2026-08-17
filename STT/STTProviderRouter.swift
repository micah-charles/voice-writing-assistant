import Foundation

struct STTProviderRouter {
    func providers(for requested: STTProvider, language: RecognitionLanguage) -> [any SpeechToTextService] {
        let whisper = WhisperKitTranscriptionService(), parakeet = ParakeetTranscriptionService(), cpp = WhisperCppTranscriptionService()
        switch requested {
        case .whisperKit: return [whisper, cpp]
        case .parakeet: return [parakeet, whisper, cpp]
        case .whisperCpp: return [cpp]
        case .automatic:
            return (language == .english ? [parakeet, whisper, cpp] : [whisper, cpp])
        }
    }
    func transcribe(audioURL: URL, settings: AppSettings, hints: [String]) async throws -> TranscriptResult {
        var errors: [String] = []
        let routed = providers(for: settings.selectedSTTProvider, language: settings.recognitionLanguage).map { provider -> any SpeechToTextService in
            provider.providerName == "WhisperKit" ? WhisperKitTranscriptionService(model: settings.whisperModel) : provider
        }
        for provider in routed {
            do { return try await provider.transcribe(audioURL: audioURL, language: settings.recognitionLanguage, vocabularyHints: hints) }
            catch { errors.append("\(provider.providerName): \(error.localizedDescription)") }
        }
        throw SpeechToTextError.failed(errors.joined(separator: "\n"))
    }
    func warm(settings: AppSettings) async throws {
        if settings.selectedSTTProvider == .automatic, settings.recognitionLanguage == .english { try await ParakeetTranscriptionService().warm(); return }
        guard settings.selectedSTTProvider == .automatic || settings.selectedSTTProvider == .whisperKit else { return }
        try await WhisperKitTranscriptionService(model: settings.whisperModel).warm()
    }
}
