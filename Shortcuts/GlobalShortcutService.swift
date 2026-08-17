import Carbon.HIToolbox

/// Registers the shortcuts with macOS instead of passively monitoring every key event.
/// This is more reliable for a menu-bar app and lets macOS reject a real shortcut collision.
final class GlobalShortcutService {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onTransformPress: (() -> Void)?
    var onTransformRelease: (() -> Void)?
    var onCancel: (() -> Void)?
    var onRegistrationFailure: ((String) -> Void)?
    var toggleMode = false

    private static let signature: OSType = 0x5A544C43 // "ZTLC"
    private enum ShortcutID: UInt32 { case dictate = 1, transform = 2 }
    private var eventHandler: EventHandlerRef?
    private var dictationHotKey: EventHotKeyRef?
    private var transformHotKey: EventHotKeyRef?

    func start() {
        guard eventHandler == nil else { return }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let handlerStatus = eventTypes.withUnsafeMutableBufferPointer {
            InstallEventHandler(GetApplicationEventTarget(), globalShortcutEventHandler, $0.count, $0.baseAddress, userData, &eventHandler)
        }
        guard handlerStatus == noErr else {
            onRegistrationFailure?("Voice Writing Assistant could not register its keyboard shortcuts (error \(handlerStatus)).")
            return
        }

        let dictateStatus = RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(controlKey), hotKeyID(.dictate), GetApplicationEventTarget(), 0, &dictationHotKey)
        let transformStatus = RegisterEventHotKey(UInt32(kVK_ANSI_E), UInt32(controlKey | optionKey), hotKeyID(.transform), GetApplicationEventTarget(), 0, &transformHotKey)
        guard dictateStatus == noErr, transformStatus == noErr else {
            stop()
            onRegistrationFailure?("The shortcut is already used by another app. Quit that app, then reopen Voice Writing Assistant.")
            return
        }
    }

    func stop() {
        if let dictationHotKey { UnregisterEventHotKey(dictationHotKey) }
        if let transformHotKey { UnregisterEventHotKey(transformHotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        dictationHotKey = nil
        transformHotKey = nil
        eventHandler = nil
    }

    private func hotKeyID(_ id: ShortcutID) -> EventHotKeyID {
        EventHotKeyID(signature: Self.signature, id: id.rawValue)
    }

    fileprivate func handle(event: EventRef?) {
        guard let event else { return }
        var hotKey = EventHotKeyID()
        let status = withUnsafeMutablePointer(to: &hotKey) {
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, $0)
        }
        guard status == noErr, hotKey.signature == Self.signature,
              let id = ShortcutID(rawValue: hotKey.id) else { return }
        let isPress = GetEventKind(event) == UInt32(kEventHotKeyPressed)
        switch (id, isPress) {
        case (.dictate, true): onPress?()
        case (.dictate, false) where !toggleMode: onRelease?()
        case (.transform, true): onTransformPress?()
        case (.transform, false): onTransformRelease?()
        default: break
        }
    }
}

private func globalShortcutEventHandler(_: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData else { return noErr }
    let service = Unmanaged<GlobalShortcutService>.fromOpaque(userData).takeUnretainedValue()
    service.handle(event: event)
    return noErr
}
