import Foundation

protocol SpeechToTextService: Sendable {
    var providerName: String { get }
    func transcribe(audioURL: URL, language: RecognitionLanguage, vocabularyHints: [String]) async throws -> TranscriptResult
    func readiness() async -> ProviderReadiness
}

struct ProviderReadiness: Sendable, Equatable { let ready: Bool; let detail: String }
enum SpeechToTextError: LocalizedError { case unavailable(String), failed(String)
    var errorDescription: String? { switch self { case .unavailable(let value): "\(value) is unavailable. Configure a local STT provider in Settings."; case .failed(let value): value } }
}
