import SwiftUI
import AppKit

struct MascotView: View {
    @Environment(EventBus.self) private var bus
    @Environment(PreferencesStore.self) private var preferences

    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var state: MascotState {
        MascotState(
            hasAttention: bus.hasActiveAttention,
            workingCount: bus.workingCount,
            lastKind: bus.lastKind,
            lastEventAt: bus.lastEventAt,
            now: now
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(state.tint.opacity(0.4), lineWidth: 1))
                .frame(width: 96, height: 96)
                .shadow(radius: 6, y: 2)

            VStack(spacing: 1) {
                Image(systemName: state.symbol)
                    .font(.system(size: 38))
                    .foregroundStyle(state.tint)
                    .contentTransition(.symbolEffect(.replace))
                    .modifier(MascotMotion(state: state))
                if let caption = state.caption {
                    Text(caption)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(state.tint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.3), value: state)
        }
        .frame(width: 120, height: 120)
        .contentShape(Circle())
        .onReceive(ticker) { now = $0 }
        .onTapGesture {
            bus.acknowledge()
            WindowOpener.shared.focus()
        }
        .contextMenu {
            Button("Open Dashboard") {
                bus.acknowledge()
                WindowOpener.shared.focus()
            }
            Button("Hide Mascot") { preferences.mascotEnabled = false }
        }
        .help("Perch — click to open the dashboard")
    }
}

private struct MascotMotion: ViewModifier {
    let state: MascotState
    @State private var animate = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(state == .calling ? (animate ? 9 : -9) : 0))
            .offset(y: state == .happy ? (animate ? -7 : 0) : 0)
            .scaleEffect(state == .sleeping ? (animate ? 1.05 : 0.97) : 1)
            .opacity(state == .dozing ? (animate ? 0.55 : 1.0) : 1.0)
            .animation(animation(for: state), value: animate)
            .onAppear { animate = true }
            .onChange(of: state) { _, _ in
                animate = false
                DispatchQueue.main.async { animate = true }
            }
    }

    private func animation(for state: MascotState) -> Animation {
        switch state {
        case .calling: return .easeInOut(duration: 0.25).repeatForever(autoreverses: true)
        case .happy: return .interpolatingSpring(stiffness: 200, damping: 6).repeatCount(4, autoreverses: true)
        case .sleeping: return .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
        case .dozing: return .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
        }
    }
}
