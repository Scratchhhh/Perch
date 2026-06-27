import SwiftUI

enum MenuBarState: Equatable {
    case calm
    case thinking
    case attention

    var symbolName: String {
        switch self {
        case .calm: return "bird"
        case .thinking: return "bird.fill"
        case .attention: return "exclamationmark.bubble.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .calm: return "Perch: idle"
        case .thinking: return "Perch: agents working"
        case .attention: return "Perch: an agent needs you"
        }
    }
}

struct MenuBarLabel: View {
    let state: MenuBarState
    var badgeCount: Int = 0

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: state.symbolName)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))
                .modifier(StateEffect(state: state))
            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.system(size: 11, weight: .bold).monospacedDigit())
            }
        }
        .animation(.smooth(duration: 0.3), value: state)
        .animation(.smooth(duration: 0.3), value: badgeCount)
        .accessibilityLabel(badgeCount > 0 ? "\(state.accessibilityLabel), \(badgeCount) waiting" : state.accessibilityLabel)
    }
}

private struct StateEffect: ViewModifier {
    let state: MenuBarState

    func body(content: Content) -> some View {
        switch state {
        case .attention:
            content.symbolEffect(.pulse, options: .repeating)
        case .thinking:
            content.symbolEffect(.variableColor.iterative, options: .repeating)
        case .calm:
            content
        }
    }
}
