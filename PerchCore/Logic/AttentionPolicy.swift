import Foundation

/// Decides whether the "needs you" alert (the mascot's calling pose and the menu-bar attention
/// icon) should currently be active. An alert is active only while there is at least one unseen
/// waiting session AND the most recent attention arrived within the time-to-live — so it both
/// clears when acknowledged (unseen count drops to zero) and settles on its own after the TTL.
public enum AttentionPolicy {
    public static let defaultTTL: TimeInterval = 20

    public static func isActive(
        unseenCount: Int,
        lastAttentionAt: Date?,
        now: Date,
        ttl: TimeInterval = defaultTTL
    ) -> Bool {
        guard unseenCount > 0, let lastAttentionAt else { return false }
        return now.timeIntervalSince(lastAttentionAt) < ttl
    }
}
