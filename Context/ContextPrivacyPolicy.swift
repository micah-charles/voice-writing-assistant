import Foundation

struct ContextPrivacyPolicy {
    func filter(_ context: CapturedContext, settings: AppSettings) -> CapturedContext {
        // Selection in browser/chat editors can be an entire long conversation. Limit it
        // just like clipboard context so processing remains responsive and predictable.
        let selectedText = settings.useSelectedTextContext ? context.selectedText?.prefix(settings.clipboardCharacterLimit).description : nil
        return CapturedContext(activeApplicationName: settings.useActiveAppContext ? context.activeApplicationName : nil, bundleIdentifier: settings.useActiveAppContext ? context.bundleIdentifier : nil, windowTitle: settings.useWindowTitle ? context.windowTitle : nil, selectedText: selectedText, clipboardText: settings.useClipboardContext ? context.clipboardText?.prefix(settings.clipboardCharacterLimit).description : nil, browserURL: settings.useBrowserURL ? context.browserURL : nil)
    }
}
