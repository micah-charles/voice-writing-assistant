import Foundation

struct PersonalDictionaryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var term: String
    var preferredForm: String
    var aliases: [String]
    var category: String?
}
