import Foundation

/// What the mascot is expressing right now. Kept UI-free (no SwiftUI) so the kind→mood mapping is
/// pure and testable; the app layer maps each mood to a symbol, tint, caption and motion.
public enum MascotMood: String, Sendable, Equatable, CaseIterable {
    /// Nothing happening — the bird dozes (Zzz).
    case idle
    /// At least one agent is actively working.
    case working
    /// An agent just finished — a short celebratory flash.
    case happy
    /// An agent is asking for input (a `Notification`/needsInput prompt).
    case asking
    /// An agent is requesting permission to do something.
    case permission
    /// An agent is blocked / errored and needs a decision.
    case alert
}

/// Decides the mascot mood from the live session signals. Attention wins over everything, then
/// active work, then a brief post-finish celebration, then idle. The previous logic put the bird
/// to *sleep* while agents were working — this is the corrected mapping.
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
