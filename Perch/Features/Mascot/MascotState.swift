import SwiftUI
import PerchCore

/// The three offered mascot sizes. Stored as a raw `Double` scale in preferences so the value is
/// future-proof, but presented as discrete S/M/L choices.
enum MascotSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var scale: Double {
        switch self {
        case .small: return 0.75
        case .medium: return 1.0
        case .large: return 1.5
        }
    }

    var label: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }

    static func closest(to scale: Double) -> MascotSize {
        allCases.min { abs($0.scale - scale) < abs($1.scale - scale) } ?? .medium
    }
}

/// App-side presentation for the pure `MascotMood` (defined and tested in PerchCore). Each mood
/// gets a distinct SF Symbol, tint and caption so the different event types are visually telling
/// apart at a glance — no custom assets required.
extension MascotMood {
    var symbol: String {
        switch self {
        case .idle: return "bird"
        case .working: return "bird.fill"
        case .happy: return "bird.fill"
        case .asking: return "questionmark.circle.fill"
        case .permission: return "hand.raised.fill"
        case .alert: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle: return .gray
        case .working: return .blue
        case .happy: return .green
        case .asking: return .orange
        case .permission: return .orange
        case .alert: return .red
        }
    }

    var caption: String? {
        switch self {
        case .idle: return "Zzz"
        case .working: return "…"
        case .happy: return "Done!"
        case .asking: return "?"
        case .permission: return "Allow?"
        case .alert: return "Blocked"
        }
    }
}
