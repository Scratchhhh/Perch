import SwiftUI
import PerchCore

/// What the bird is doing, derived from the live session counts. "happy" is a short flash after a
/// finish before settling back to dozing.
enum MascotState: Equatable {
    case sleeping
    case happy
    case calling
    case dozing

    init(workingCount: Int, waitingCount: Int, lastKind: EventKind?, lastEventAt: Date?, now: Date) {
        if waitingCount > 0 {
            self = .calling
        } else if workingCount > 0 {
            self = .sleeping
        } else if lastKind == .finished, let lastEventAt, now.timeIntervalSince(lastEventAt) < 6 {
            self = .happy
        } else {
            self = .dozing
        }
    }

    var symbol: String {
        switch self {
        case .sleeping: return "bird.fill"
        case .happy: return "bird.fill"
        case .calling: return "bird.fill"
        case .dozing: return "bird"
        }
    }

    var tint: Color {
        switch self {
        case .sleeping: return .indigo
        case .happy: return .green
        case .calling: return .orange
        case .dozing: return .gray
        }
    }

    var caption: String? {
        switch self {
        case .sleeping: return "Zzz"
        case .happy: return "Done!"
        case .calling: return "Hey!"
        case .dozing: return nil
        }
    }
}
