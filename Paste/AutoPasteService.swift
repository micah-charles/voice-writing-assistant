import AppKit
import ApplicationServices
import Foundation

enum AutoPasteError: LocalizedError {
    case accessibilityDenied, keyboardPasteUnavailable
    var errorDescription: String? {
        switch self {
        case .accessibilityDenied: "Text copied. Enable Accessibility permission for automatic paste."
        case .keyboardPasteUnavailable: "Text copied. The system paste event could not be created."
        }
    }
}
enum PasteMethod {
    case accessibilityInsertion, commandVPaste
    var description: String {
        switch self {
        case .accessibilityInsertion: "Inserted directly using Accessibility"
        case .commandVPaste: "Used Command-V paste fallback"
        }
    }
}
final class AutoPasteService {
    private let clipboard = ClipboardService()
    func paste(_ text: String, targetBundleIdentifier: String?, restoreClipboard: Bool) async throws -> PasteMethod {
        guard AXIsProcessTrusted() else { clipboard.copy(text); throw AutoPasteError.accessibilityDenied }
        var target: NSRunningApplication?
        if let targetBundleIdentifier,
           let application = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleIdentifier).first {
            target = application
            application.activate()
            try? await Task.sleep(for: .milliseconds(250))
        }
        if let target, insert(text, into: target) { return .accessibilityInsertion }
        let previous = clipboard.snapshot()
        clipboard.copy(text)
        guard let source = CGEventSource(stateID: .hidSystemState), let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true), let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { throw AutoPasteError.keyboardPasteUnavailable }
        down.flags = .maskCommand; up.flags = .maskCommand; down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
        if restoreClipboard { try? await Task.sleep(for: .milliseconds(500)); clipboard.restore(previous) }
        return .commandVPaste
    }

    func undoLastPaste(targetBundleIdentifier: String?) async throws {
        guard AXIsProcessTrusted() else { throw AutoPasteError.accessibilityDenied }
        if let targetBundleIdentifier,
           let application = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleIdentifier).first {
            application.activate()
            try? await Task.sleep(for: .milliseconds(180))
        }
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 6, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 6, keyDown: false) else {
            throw AutoPasteError.keyboardPasteUnavailable
        }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
    }

    private func insert(_ text: String, into application: NSRunningApplication) -> Bool {
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(applicationElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let focusedElement else { return false }
        return AXUIElementSetAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
    }
}
