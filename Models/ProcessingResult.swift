import Foundation

struct ProcessingResult: Codable, Equatable {
    let text: String
    let provider: String
    let latency: TimeInterval
    let usedFallback: Bool
}
