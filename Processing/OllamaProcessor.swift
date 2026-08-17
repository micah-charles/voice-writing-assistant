import Foundation

struct OllamaProcessor: TextProcessingService {
    let endpoint: String
    let model: String
    let timeout: TimeInterval
    var providerName: String { "Ollama" }
    func readiness() async -> ProviderReadiness {
        guard let url = URL(string: endpoint + "/api/tags") else { return ProviderReadiness(ready: false, detail: "Invalid endpoint") }
        var request = URLRequest(url: url); request.timeoutInterval = 3
        do { let (_, response) = try await URLSession.shared.data(for: request); return ProviderReadiness(ready: (response as? HTTPURLResponse)?.statusCode == 200, detail: "Reachable at \(endpoint)") }
        catch { return ProviderReadiness(ready: false, detail: "Not reachable") }
    }
    func process(rawText: String, context: CapturedContext, mode: AppMode, style: ProcessingStyle, outputLanguage: OutputLanguage) async throws -> ProcessingResult {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ProcessRunnerError.failed("Choose an Ollama model in Settings.") }
        let started = ContinuousClock.now
        let text = try await chat(PromptBuilder().dictation(rawText: rawText, context: context, mode: mode, style: style, outputLanguage: outputLanguage))
        return ProcessingResult(text: OutputSanitizer().sanitize(text), provider: providerName, latency: started.duration(to: .now).timeInterval, usedFallback: false)
    }
    func transform(selectedText: String, instruction: String, context: CapturedContext) async throws -> ProcessingResult {
        let started = ContinuousClock.now
        let text = try await chat(PromptBuilder().transform(selectedText: selectedText, instruction: instruction, context: context))
        return ProcessingResult(text: OutputSanitizer().sanitize(text), provider: providerName, latency: started.duration(to: .now).timeInterval, usedFallback: false)
    }
    private func chat(_ prompt: String) async throws -> String {
        guard let url = URL(string: endpoint + "/api/chat") else { throw ProcessRunnerError.failed("Invalid Ollama endpoint.") }
        let payload: [String: Any] = ["model": model, "stream": false, "messages": [["role": "user", "content": prompt]]]
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = timeout; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, 200..<300 ~= status else { throw ProcessRunnerError.failed("Ollama returned an error.") }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let message = object["message"] as? [String: Any], let text = message["content"] as? String else { throw ProcessRunnerError.failed("Ollama returned an unexpected response.") }
        return text
    }
}
