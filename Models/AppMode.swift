import Foundation

enum AppMode: String, Codable, CaseIterable, Identifiable {
    case general, email, chat, technical, document, note, selectedTextTransform
    var id: String { rawValue }
    var displayName: String { rawValue.replacingOccurrences(of: "Text", with: " Text").capitalized }
}
