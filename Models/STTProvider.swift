import Foundation

enum STTProvider: String, Codable, CaseIterable, Identifiable { case automatic, whisperKit, parakeet, whisperCpp
    var id: String { rawValue }
    var displayName: String { switch self { case .automatic: "Automatic"; case .whisperKit: "WhisperKit"; case .parakeet: "Parakeet"; case .whisperCpp: "whisper.cpp" } }
}
