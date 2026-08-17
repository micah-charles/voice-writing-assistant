import AppKit
import Foundation

/// Reads only the address of the front document/tab when the user has enabled browser context.
/// macOS may request Automation permission; failures intentionally return nil.
struct BrowserContextService {
    func currentURL(for bundleIdentifier: String?) -> String? {
        let source: String?
        switch bundleIdentifier {
        case "com.apple.Safari": source = "tell application \"Safari\" to return URL of front document"
        case "com.google.Chrome": source = "tell application \"Google Chrome\" to return URL of active tab of front window"
        case "com.microsoft.edgemac": source = "tell application \"Microsoft Edge\" to return URL of active tab of front window"
        default: source = nil
        }
        guard let source, let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        return script.executeAndReturnError(&error).stringValue
    }
}
