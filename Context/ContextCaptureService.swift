import AppKit
import ApplicationServices
import Foundation

actor ContextCaptureService {
    func capture(settings: AppSettings) async -> CapturedContext {
        let app = NSWorkspace.shared.frontmostApplication
        let pid = app?.processIdentifier ?? 0
        let element = AXUIElementCreateApplication(pid)
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &titleValue)
        var windowTitle: String?
        if let window = titleValue { var value: CFTypeRef?; AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &value); windowTitle = value as? String }
        var focused: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXFocusedUIElementAttribute as CFString, &focused)
        var selected: String?
        if let focused { var value: CFTypeRef?; AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &value); selected = value as? String }
        let clipboard = settings.useClipboardContext ? NSPasteboard.general.string(forType: .string) : nil
        let browserURL = settings.useBrowserURL ? BrowserContextService().currentURL(for: app?.bundleIdentifier) : nil
        let raw = CapturedContext(activeApplicationName: app?.localizedName, bundleIdentifier: app?.bundleIdentifier, windowTitle: windowTitle, selectedText: selected, clipboardText: clipboard, browserURL: browserURL)
        return ContextPrivacyPolicy().filter(raw, settings: settings)
    }
}
