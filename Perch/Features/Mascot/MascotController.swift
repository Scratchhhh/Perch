import AppKit
import SwiftUI

/// Hosts the mascot in a borderless, transparent, always-on-top panel that the user can drag around.
@MainActor
final class MascotController {
    private var panel: NSPanel?
    private let eventBus: EventBus
    private let preferences: PreferencesStore

    init(eventBus: EventBus, preferences: PreferencesStore) {
        self.eventBus = eventBus
        self.preferences = preferences
    }

    func setVisible(_ visible: Bool) {
        if visible {
            show()
        } else {
            hide()
        }
    }

    private func show() {
        guard panel == nil else { return }

        let root = MascotView()
            .environment(eventBus)
            .environment(preferences)
        let hosting = NSHostingController(rootView: root)
        hosting.view.frame = NSRect(x: 0, y: 0, width: 120, height: 120)

        let panel = NSPanel(
            contentRect: hosting.view.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.contentViewController = hosting

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - 150, y: frame.maxY - 160))
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
