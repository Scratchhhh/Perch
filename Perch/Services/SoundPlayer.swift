import AppKit

/// Distinct system sounds for the two outcomes that matter. Using named system sounds keeps the
/// bundle asset-free while still giving "done" and "needs you" different voices.
@MainActor
enum SoundPlayer {
    enum Cue {
        case done
        case attention

        var soundName: String {
            switch self {
            case .done: return "Glass"
            case .attention: return "Submarine"
            }
        }
    }

    static func play(_ cue: Cue) {
        NSSound(named: cue.soundName)?.play()
    }
}
