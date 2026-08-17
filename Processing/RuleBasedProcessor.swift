import Foundation

struct RuleBasedProcessor: TextProcessingService {
    let providerName = "Rule-based (AI unavailable)"
    func readiness() async -> ProviderReadiness { ProviderReadiness(ready: true, detail: "Always available locally") }
    func process(rawText: String, context: CapturedContext, mode: AppMode, style: ProcessingStyle, outputLanguage: OutputLanguage) async throws -> ProcessingResult {
        let started = ContinuousClock.now
        let lines = rawText.split(separator: "\n", omittingEmptySubsequences: false).map { line in line.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
        let result = lines.joined(separator: "\n").replacingOccurrences(of: #"\s+([,.;:!?])"#, with: "$1", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        return ProcessingResult(text: result, provider: providerName, latency: started.duration(to: .now).timeInterval, usedFallback: false)
    }
}
