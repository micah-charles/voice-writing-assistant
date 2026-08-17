import Foundation

struct ModeClassifier {
    func classify(context: CapturedContext, transform: Bool = false) -> AppMode {
        if transform { return .selectedTextTransform }
        let id = (context.bundleIdentifier ?? "").lowercased(); let name = (context.activeApplicationName ?? "").lowercased()
        if ["outlook", "mail", "gmail"].contains(where: { id.contains($0) || name.contains($0) }) { return .email }
        if ["teams", "slack", "messages", "discord"].contains(where: { id.contains($0) || name.contains($0) }) { return .chat }
        if ["vscode", "xcode", "terminal", "iterm", "codex"].contains(where: { id.contains($0) || name.contains($0) }) { return .technical }
        if ["word", "pages", "docs"].contains(where: { id.contains($0) || name.contains($0) }) { return .document }
        if ["notes", "obsidian", "notion"].contains(where: { id.contains($0) || name.contains($0) }) { return .note }
        return .general
    }
}
