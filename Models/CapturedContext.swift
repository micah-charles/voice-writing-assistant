import Foundation

struct CapturedContext: Codable, Equatable {
    var activeApplicationName: String?
    var bundleIdentifier: String?
    var windowTitle: String?
    var selectedText: String?
    var clipboardText: String?
    var browserURL: String?
    static let empty = CapturedContext()
}
