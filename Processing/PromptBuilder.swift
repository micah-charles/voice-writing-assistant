import Foundation

struct PromptBuilder {
    func dictation(rawText: String, context: CapturedContext, mode: AppMode, style: ProcessingStyle, outputLanguage: OutputLanguage = .preserveSpokenLanguage) -> String {
        var lines = ["You are a careful voice dictation editor.", "Transform the user's raw speech into clean written text suitable for the current context.", "Rules:", "- Preserve the user's original meaning.", "- Do not invent facts, names, dates, commitments, prices, decisions, greetings, or sign-offs.", "- Remove filler words and false starts; fix punctuation and grammar.", "- Preserve technical terms, code identifiers, paths, acronyms, proper nouns, and mixed Chinese/English.", "- Return only the final text.", "MODE: \(mode.rawValue)", "STYLE: \(style.rawValue)"]
        if mode == .email { lines += ["EMAIL MODE: professional, natural, concise; do not invent a recipient or sign-off."] }
        if mode == .chat { lines += ["CHAT MODE: conversational, compact, and natural."] }
        if mode == .technical { lines += ["TECHNICAL MODE: never simplify or alter identifiers, commands, paths, or acronyms."] }
        if mode == .document { lines += ["DOCUMENT MODE: use complete, readable prose."] }
        if mode == .note { lines += ["NOTE MODE: concise shorthand or bullets are acceptable when natural."] }
        switch outputLanguage {
        case .preserveSpokenLanguage: lines += ["OUTPUT LANGUAGE: Preserve the user's spoken language. Do not translate unless explicitly instructed."]
        case .english: lines += ["OUTPUT LANGUAGE: Translate the final text into natural English. Preserve proper nouns, product names, technical terms, code identifiers, commands, and paths unchanged."]
        case .cantoneseWritten: lines += ["OUTPUT LANGUAGE: Return polished Cantonese written in Traditional Chinese. Preserve English product and technical terms."]
        case .formalTraditionalChinese: lines += ["OUTPUT LANGUAGE: Return polished formal Traditional Chinese. Preserve English product and technical terms."]
        }
        append(&lines, label: "ACTIVE APP", value: context.activeApplicationName)
        append(&lines, label: "WINDOW TITLE", value: context.windowTitle)
        append(&lines, label: "SELECTED CONTEXT", value: context.selectedText)
        append(&lines, label: "CLIPBOARD CONTEXT", value: context.clipboardText)
        append(&lines, label: "BROWSER URL", value: context.browserURL)
        lines += ["RAW DICTATION:", rawText]
        return lines.joined(separator: "\n")
    }
    func transform(selectedText: String, instruction: String, context: CapturedContext) -> String {
        var lines = ["You are editing existing text according to a spoken instruction.", "Rules:", "- Follow the spoken instruction exactly.", "- Preserve factual meaning unless the instruction explicitly asks for a transformation.", "- Do not invent facts.", "- Return only replacement text; do not explain.", "CURRENT TEXT:", selectedText, "SPOKEN INSTRUCTION:", instruction]
        append(&lines, label: "ACTIVE APP", value: context.activeApplicationName)
        return lines.joined(separator: "\n")
    }
    private func append(_ lines: inout [String], label: String, value: String?) { if let value, !value.isEmpty { lines += ["\(label):", value] } }
}
