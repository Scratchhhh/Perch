import Foundation

/// Seam for future remote notifiers (Telegram, ntfy). They are `Notifier`s like any other, so the
/// event bus needs no changes to gain them — only a concrete transport and a settings panel.
///
/// Deliberately unimplemented in v1: Perch ships local-only with zero network egress beyond
/// localhost. These types exist to keep the architectural shape honest, not to hint at hidden
/// behaviour.
@MainActor
protocol RemoteNotifier: Notifier {
    var isConfigured: Bool { get }
}

enum RemoteNotifierAvailability {
    case comingSoon
}

/// Placeholder describing the planned Telegram bot notifier. Not wired into the bus.
@MainActor
final class TelegramNotifier: RemoteNotifier {
    let id = "telegram"
    let availability: RemoteNotifierAvailability = .comingSoon
    private(set) var isConfigured = false

    func deliver(_ content: NotificationContent) {
        // Intentionally empty: remote delivery is not part of v1.
    }
}

/// Placeholder describing the planned ntfy notifier. Not wired into the bus.
@MainActor
final class NtfyNotifier: RemoteNotifier {
    let id = "ntfy"
    let availability: RemoteNotifierAvailability = .comingSoon
    private(set) var isConfigured = false

    func deliver(_ content: NotificationContent) {
        // Intentionally empty: remote delivery is not part of v1.
    }
}
