import AppKit
import Foundation

struct ClipboardSnapshot { let string: String? }
final class ClipboardService {
    func snapshot() -> ClipboardSnapshot { ClipboardSnapshot(string: NSPasteboard.general.string(forType: .string)) }
    func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
    func restore(_ snapshot: ClipboardSnapshot) { guard let string = snapshot.string else { return }; copy(string) }
}
