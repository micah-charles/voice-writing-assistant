import Foundation

struct TextProcessorRouter {
    /// Emits each successful AI result as it becomes available.  In fastest-response
    /// mode both remote Codex and local Ollama run concurrently; rule-only cleanup is
    /// emitted only when neither AI returns a result.
    func race(rawText: String, context: CapturedContext, mode: AppMode, settings: AppSettings) -> AsyncStream<ProcessingResult> {
        let timeout = TimeInterval(settings.processingTimeoutSeconds)
        let codex = CodexCLIProcessor(timeout: timeout)
        let ollama = OllamaProcessor(endpoint: settings.ollamaEndpoint, model: settings.ollamaModel, timeout: timeout)
        let services: [any TextProcessingService]
        switch settings.selectedTextProcessor {
        case .ruleBased: services = []
        case .codexCLI: services = [codex]
        case .ollama: services = [ollama]
        case .automatic:
            // Only Automatic mode races both engines. Explicit choices must be
            // respected, so users can verify or require a particular provider.
            services = [codex, ollama]
        }
        return AsyncStream { continuation in
            let task = Task {
                var receivedAIResult = false
                await withTaskGroup(of: ProcessingResult?.self) { group in
                    for service in services {
                        group.addTask {
                            try? await service.process(rawText: rawText, context: context, mode: mode, style: settings.processingStyle, outputLanguage: settings.outputLanguage)
                        }
                    }
                    for await result in group {
                        if let result {
                            receivedAIResult = true
                            continuation.yield(result)
                        }
                    }
                }
                if !receivedAIResult {
                    let fallback = try? await RuleBasedProcessor().process(rawText: rawText, context: context, mode: mode, style: settings.processingStyle, outputLanguage: settings.outputLanguage)
                    if let fallback { continuation.yield(fallback) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func process(rawText: String, context: CapturedContext, mode: AppMode, settings: AppSettings) async -> ProcessingResult {
        let candidates: [any TextProcessingService]
        let timeout = TimeInterval(settings.processingTimeoutSeconds)
        let codex = CodexCLIProcessor(timeout: timeout)
        let ollama = OllamaProcessor(endpoint: settings.ollamaEndpoint, model: settings.ollamaModel, timeout: timeout)
        // Automatic mode honours the user's ChatGPT/Codex sign-in first; local Ollama
        // is the private fallback if Codex is unavailable or times out.
        switch settings.selectedTextProcessor { case .codexCLI: candidates = [codex, ollama, RuleBasedProcessor()]; case .ollama: candidates = [ollama, RuleBasedProcessor()]; case .ruleBased: candidates = [RuleBasedProcessor()]; case .automatic: candidates = [codex, ollama, RuleBasedProcessor()] }
        for (index, processor) in candidates.enumerated() { if let result = try? await processor.process(rawText: rawText, context: context, mode: mode, style: settings.processingStyle, outputLanguage: settings.outputLanguage) { return ProcessingResult(text: result.text, provider: result.provider, latency: result.latency, usedFallback: index > 0) } }
        return ProcessingResult(text: rawText, provider: "Raw", latency: 0, usedFallback: true)
    }
    func transform(selectedText: String, instruction: String, context: CapturedContext, settings: AppSettings) async -> ProcessingResult {
        if settings.selectedTextProcessor != .ruleBased {
            if settings.selectedTextProcessor != .ollama, let result = try? await CodexCLIProcessor(timeout: TimeInterval(settings.processingTimeoutSeconds)).transform(selectedText: selectedText, instruction: instruction, context: context) { return result }
            let ollama = OllamaProcessor(endpoint: settings.ollamaEndpoint, model: settings.ollamaModel, timeout: TimeInterval(settings.processingTimeoutSeconds))
            if let result = try? await ollama.transform(selectedText: selectedText, instruction: instruction, context: context) { return result }
        }
        return ProcessingResult(text: selectedText, provider: "Rule-based (no semantic transform)", latency: 0, usedFallback: true)
    }
}
