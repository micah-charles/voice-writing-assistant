import AppKit
import SwiftUI

@MainActor
final class RecorderPanelController {
    private let panel: NSPanel
    init(state: AppState) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 270, height: 90), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .windowBackgroundColor; panel.hasShadow = true; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]; panel.hidesOnDeactivate = false; panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: RecorderOverlayView().environmentObject(state))
    }
    func show() { panel.center(); panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }
}
