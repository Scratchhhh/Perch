import AppKit
import SwiftUI
import Observation

/// Hosts the mascot in a borderless, transparent, always-on-top panel that the user can drag around.
/// Watches `mascotScale` so changing the size in Settings or the context menu resizes the live panel
/// without recreating it, keeping the bird anchored to whichever corner the user parked it at.
@MainActor
final class MascotController {
    private var panel: NSPanel?
    private let eventBus: EventBus
    private let preferences: PreferencesStore

    private let baseSize: CGFloat = 120

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

    private var currentSize: CGFloat {
        baseSize * CGFloat(preferences.mascotScale)
    }

    private func show() {
        guard panel == nil else { return }

        let root = MascotView()
            .environment(eventBus)
            .environment(preferences)
        let hosting = NSHostingController(rootView: root)
        let size = currentSize
        hosting.view.frame = NSRect(x: 0, y: 0, width: size, height: size)

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
            panel.setFrameOrigin(NSPoint(x: frame.maxX - size - 30, y: frame.maxY - size - 40))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        observeScale()
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func observeScale() {
        withObservationTracking {
            _ = preferences.mascotScale
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyScale()
                self.observeScale()
            }
        }
    }

    /// Resize the panel in place, keeping its top-right corner fixed so the mascot grows/shrinks
    /// toward its current screen position rather than jumping.
    private func applyScale() {
        guard let panel else { return }
        let size = currentSize
        let old = panel.frame
        let topRight = NSPoint(x: old.maxX, y: old.maxY)
        let newFrame = NSRect(x: topRight.x - size, y: topRight.y - size, width: size, height: size)
        panel.setFrame(newFrame, display: true, animate: true)
        panel.contentViewController?.view.frame = NSRect(x: 0, y: 0, width: size, height: size)
    }
}
