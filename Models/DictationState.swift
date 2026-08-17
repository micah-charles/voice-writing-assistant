import Foundation

enum DictationState: Equatable {
    case idle, starting, recording, transcribing, capturingContext, processing, normalizing, pasting, awaitingReview, completed
    case failed(String)

    var canStart: Bool { self == .idle || self == .completed || isFailure }
    var isBusy: Bool { !canStart }
    var isFailure: Bool { if case .failed = self { return true }; return false }
    var displayText: String {
        switch self {
        case .idle: return "Ready — hold Control + R"
        case .starting: return "Starting microphone…"
        case .recording: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .capturingContext: return "Understanding context…"
        case .processing: return "Cleaning text…"
        case .normalizing: return "Normalizing language…"
        case .pasting: return "Pasting…"
        case .awaitingReview: return "Review result before pasting"
        case .completed: return "Done"
        case .failed(let message): return message
        }
    }
}
