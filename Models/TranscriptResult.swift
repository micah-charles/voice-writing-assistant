import Foundation

struct TranscriptResult: Codable, Equatable {
    let text: String
    let language: String?
    let duration: TimeInterval?
    let confidence: Double?
    let provider: String
}
