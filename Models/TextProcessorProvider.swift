import Foundation

enum TextProcessorProvider: String, Codable, CaseIterable, Identifiable { case automatic, codexCLI, ollama, ruleBased
    var id: String { rawValue }
    var displayName: String { switch self { case .automatic: "Automatic fallback"; case .codexCLI: "Codex CLI"; case .ollama: "Ollama (local)"; case .ruleBased: "Rule-only" } }
}
