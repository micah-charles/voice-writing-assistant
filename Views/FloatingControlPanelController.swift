import AppKit
import SwiftUI

@MainActor
final class FloatingControlPanelController {
    private let panel: NSPanel

    init(state: AppState) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 70, height: 70), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.setFrameAutosaveName("ZeroTypeLocalFloatingControl")
        panel.contentView = NSHostingView(rootView: FloatingControlView().environmentObject(state))
    }

    func show() {
        if panel.frame.origin == .zero, let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 86, y: screen.visibleFrame.maxY - 110))
        }
        panel.orderFrontRegardless()
    }

    func hide() { panel.orderOut(nil) }

    func setMenuVisible(_ visible: Bool) {
        let targetSize = visible ? NSSize(width: 650, height: 320) : NSSize(width: 70, height: 70)
        let previous = panel.frame
        let frame = NSRect(x: previous.maxX - targetSize.width, y: previous.maxY - targetSize.height, width: targetSize.width, height: targetSize.height)
        panel.setFrame(frame, display: true, animate: true)
        panel.orderFrontRegardless()
    }
}
