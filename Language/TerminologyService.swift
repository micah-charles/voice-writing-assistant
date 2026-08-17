import Foundation

struct TerminologyService {
    func normalize(_ text: String, entries: [PersonalDictionaryEntry]) -> String {
        entries.reduce(text) { result, entry in
            entry.aliases.reduce(result) { partial, alias in
                guard !alias.isEmpty else { return partial }
                return partial.replacingOccurrences(of: alias, with: entry.preferredForm, options: [.caseInsensitive, .diacriticInsensitive])
            }
        }
    }
    func hints(_ entries: [PersonalDictionaryEntry]) -> [String] { entries.flatMap { [$0.term, $0.preferredForm] + $0.aliases }.filter { !$0.isEmpty } }
}
