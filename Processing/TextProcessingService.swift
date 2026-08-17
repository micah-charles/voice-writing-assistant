import Foundation

protocol TextProcessingService: Sendable {
    var providerName: String { get }
    func process(rawText: String, context: CapturedContext, mode: AppMode, style: ProcessingStyle, outputLanguage: OutputLanguage) async throws -> ProcessingResult
    func readiness() async -> ProviderReadiness
}
