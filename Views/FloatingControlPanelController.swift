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
        // A seven-item child arc reaches about 320 pt from the Fox hub. Keep the
        // panel larger than that radius so it never clips labels at its own edge.
        let targetSize = visible ? NSSize(width: 700, height: 700) : NSSize(width: 70, height: 70)
        let previous = panel.frame
        let candidate = NSRect(x: previous.maxX - targetSize.width, y: previous.maxY - targetSize.height, width: targetSize.width, height: targetSize.height)
        panel.setFrame(clampedToVisibleScreen(candidate, near: previous), display: true, animate: true)
        panel.orderFrontRegardless()
    }

    /// The expanded panel can be dragged partly off-screen. Always clamp both the
    /// expanded and collapsed frames, so the 70 pt Fox hub remains recoverable.
    private func clampedToVisibleScreen(_ frame: NSRect, near previous: NSRect) -> NSRect {
        let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(previous) }) ?? NSScreen.main
        guard let screen else { return frame }

        let visible = screen.visibleFrame
        let margin: CGFloat = 12
        let minX = visible.minX + margin
        let minY = visible.minY + margin
        let maxX = max(minX, visible.maxX - frame.width - margin)
        let maxY = max(minY, visible.maxY - frame.height - margin)
        return NSRect(
            x: min(max(frame.origin.x, minX), maxX),
            y: min(max(frame.origin.y, minY), maxY),
            width: frame.width,
            height: frame.height
        )
    }
}
