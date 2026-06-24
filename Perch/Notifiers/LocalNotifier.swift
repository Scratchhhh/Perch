import Foundation
import UserNotifications
import PerchCore

/// Posts native banners with sound and contextual action buttons.
@MainActor
final class LocalNotifier: NSObject, Notifier {
    let id = "local"

    private let center = UNUserNotificationCenter.current()
    private let preferences: PreferencesStore

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

        playSound(for: content.category)
    }

    private func playSound(for category: NotificationContent.Category) {
        guard preferences.soundsEnabled else { return }
        switch category {
        case .done: SoundPlayer.play(.done)
        case .attention: SoundPlayer.play(.attention)
        case .info: break
        }
    }

    private func registerCategories() {
        let open = UNNotificationAction(
            identifier: NotificationRouter.openProjectAction,
            title: "Open Project",
            options: [.foreground]
        )
        let markDone = UNNotificationAction(
            identifier: NotificationRouter.markDoneAction,
            title: "Got It",
            options: []
        )

        let done = UNNotificationCategory(
            identifier: CategoryID.done,
            actions: [open, markDone],
            intentIdentifiers: []
        )
        let attention = UNNotificationCategory(
            identifier: CategoryID.attention,
            actions: [open],
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
