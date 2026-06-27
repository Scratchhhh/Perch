import Foundation
import AppKit
import UserNotifications
import PerchCore

/// Posts native banners with sound and contextual action buttons.
@MainActor
final class LocalNotifier: NSObject, Notifier {
    let id = "local"

    private let center = UNUserNotificationCenter.current()
    private let preferences: PreferencesStore

    /// The app icon as PNG, attached to each banner so Perch shows up even before LaunchServices
    /// has cached the bundle icon for an accessory (menu-bar) app.
    private lazy var iconPNG: Data? = Self.makeIconPNG()

    private enum CategoryID {
        static let done = "perch.done"
        static let attention = "perch.attention"
        static let info = "perch.info"
    }

    init(preferences: PreferencesStore) {
        self.preferences = preferences
        super.init()
        center.delegate = self
        registerCategories()
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                PerchLog.notifier.error("authorization error: \(error.localizedDescription, privacy: .public)")
            } else {
                PerchLog.notifier.info("notification authorization granted=\(granted)")
            }
        }
    }

    func deliver(_ content: NotificationContent) {
        let note = UNMutableNotificationContent()
        note.title = content.title
        note.body = content.body
        note.sound = nil
        note.categoryIdentifier = categoryIdentifier(for: content.category)
        note.userInfo = [
            "sessionId": content.sessionId,
            "projectPath": content.projectPath ?? ""
        ]
        if let attachment = makeIconAttachment() {
            note.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: note,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                PerchLog.notifier.error("deliver failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        playSound(for: content)
    }

    private func playSound(for content: NotificationContent) {
        guard preferences.soundsEnabled, content.playSound else { return }
        switch content.category {
        case .done: SoundPlayer.play(.done, volume: content.soundVolume)
        case .attention: SoundPlayer.play(.attention, volume: content.soundVolume)
        case .info: break
        }
    }

    /// UNNotificationAttachment takes ownership of the file (moves it out of its location), so each
    /// banner needs its own copy rather than reusing one path.
    private func makeIconAttachment() -> UNNotificationAttachment? {
        guard let iconPNG else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("perch-icon-\(UUID().uuidString).png")
        do {
            try iconPNG.write(to: url, options: .atomic)
            return try UNNotificationAttachment(identifier: "perch-icon", url: url)
        } catch {
            PerchLog.notifier.error("icon attachment failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func makeIconPNG() -> Data? {
        let icon = NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName)
        guard let icon,
              let tiff = icon.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func registerCategories() {
        let open = UNNotificationAction(
            identifier: NotificationRouter.openProjectAction,
            title: "Open Project",
            options: [.foreground]
        )
        let openTerminal = UNNotificationAction(
            identifier: NotificationRouter.openTerminalAction,
            title: "Open in Terminal",
            options: [.foreground]
        )
        let markDone = UNNotificationAction(
            identifier: NotificationRouter.markDoneAction,
            title: "Got It",
            options: []
        )

        let done = UNNotificationCategory(
            identifier: CategoryID.done,
            actions: [openTerminal, open, markDone],
            intentIdentifiers: []
        )
        let attention = UNNotificationCategory(
            identifier: CategoryID.attention,
            actions: [openTerminal, open],
            intentIdentifiers: []
        )
        let info = UNNotificationCategory(
            identifier: CategoryID.info,
            actions: [],
            intentIdentifiers: []
        )

        center.setNotificationCategories([done, attention, info])
    }

    private func categoryIdentifier(for category: NotificationContent.Category) -> String {
        switch category {
        case .done: return CategoryID.done
        case .attention: return CategoryID.attention
        case .info: return CategoryID.info
        }
    }
}

extension LocalNotifier: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let projectPath = info["projectPath"] as? String
        let actionIdentifier = response.actionIdentifier
        await MainActor.run {
            NotificationRouter.shared.handle(actionIdentifier: actionIdentifier, projectPath: projectPath)
        }
    }
}
