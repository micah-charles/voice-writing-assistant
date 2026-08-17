import Foundation

enum ProcessingStyle: String, Codable, CaseIterable, Identifiable { case automatic, faithful, professional, conversational, technical, structured, concise
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
