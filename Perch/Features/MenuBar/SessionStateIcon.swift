import SwiftUI
import PerchCore

struct SessionStateIcon: View {
    let state: SessionState

    var body: some View {
        switch state {
        case .working:
            ProgressView()
                .controlSize(.small)
        case .waiting:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
                .symbolEffect(.pulse, options: .repeating)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .idle:
            Image(systemName: "moon.zzz.fill")
                .foregroundStyle(.secondary)
        }
    }
}

extension SessionState {
    var label: String {
        switch self {
        case .working: return "Working"
        case .waiting: return "Needs you"
        case .done: return "Done"
        case .idle: return "Idle"
        }
    }
}
