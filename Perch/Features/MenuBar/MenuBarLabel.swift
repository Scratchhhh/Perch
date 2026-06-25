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

    var body: some View {
        Image(systemName: state.symbolName)
            .symbolRenderingMode(.hierarchical)
            .contentTransition(.symbolEffect(.replace))
            .modifier(StateEffect(state: state))
            .animation(.smooth(duration: 0.3), value: state)
            .accessibilityLabel(state.accessibilityLabel)
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
