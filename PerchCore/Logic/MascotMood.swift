import Foundation

/// What the mascot is expressing. Kept UI-free so the kind-to-mood mapping is testable; the app
/// layer maps each mood to a symbol, tint, caption and motion.
public enum MascotMood: String, Sendable, Equatable, CaseIterable {
    /// Nothing happening. The bird dozes (Zzz).
    case idle
    /// At least one agent is actively working.
    case working
    /// An agent just finished. A short celebratory flash.
    case happy
    /// An agent is asking for input.
    case asking
    /// An agent is requesting permission.
    case permission
    /// An agent is blocked or errored and needs a decision.
    case alert
}

/// Derives the mascot mood from the live session signals. Attention wins, then active work, then a
/// brief post-finish celebration, then idle. The old logic put the bird to sleep while agents were
/// working; this is the corrected mapping.
public enum MascotMoodPolicy {
    public static let happyWindow: TimeInterval = 6

    public static func mood(
        hasAttention: Bool,
        attentionKind: EventKind?,
        workingCount: Int,
        lastKind: EventKind?,
        lastEventAt: Date?,
        now: Date,
        happyWindow: TimeInterval = happyWindow
    ) -> MascotMood {
        if hasAttention {
            switch attentionKind ?? lastKind {
            case .permission: return .permission
            case .blocked: return .alert
            case .needsInput: return .asking
            default: return .asking
            }
        }
        if workingCount > 0 {
            return .working
        }
        if lastKind == .finished, let lastEventAt, now.timeIntervalSince(lastEventAt) < happyWindow {
            return .happy
        }
        return .idle
    }
}
