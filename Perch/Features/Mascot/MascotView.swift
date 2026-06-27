import SwiftUI
import AppKit
import PerchCore

struct MascotView: View {
    @Environment(EventBus.self) private var bus
    @Environment(PreferencesStore.self) private var preferences

    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Base geometry at scale 1.0; everything multiplies by `scale`.
    private let baseFrame: CGFloat = 120
    private let baseCircle: CGFloat = 96
    private let baseSymbol: CGFloat = 38

    private var scale: CGFloat { CGFloat(preferences.mascotScale) }

    private var mood: MascotMood {
        MascotMoodPolicy.mood(
            hasAttention: bus.hasActiveAttention,
            attentionKind: bus.lastAttentionKind,
            workingCount: bus.workingCount,
            lastKind: bus.lastKind,
            lastEventAt: bus.lastEventAt,
            now: now
        )
    }

    var body: some View {
        let mood = mood
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(mood.tint.opacity(0.4), lineWidth: 1))
                .frame(width: baseCircle * scale, height: baseCircle * scale)
                .shadow(radius: 6, y: 2)

            VStack(spacing: 1) {
                Image(systemName: mood.symbol)
                    .font(.system(size: baseSymbol * scale))
                    .foregroundStyle(mood.tint)
                    .contentTransition(.symbolEffect(.replace))
                    .modifier(MascotMotion(mood: mood))
                if let caption = mood.caption {
                    Text(caption)
                        .font(.system(size: 11 * scale, weight: .semibold))
                        .foregroundStyle(mood.tint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.3), value: mood)
        }
        .frame(width: baseFrame * scale, height: baseFrame * scale)
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
            Picker("Size", selection: sizeBinding) {
                ForEach(MascotSize.allCases) { size in
                    Text(size.label).tag(size)
                }
            }
            Button("Hide Mascot") { preferences.mascotEnabled = false }
        }
        .help("Click to open the dashboard")
    }

    private var sizeBinding: Binding<MascotSize> {
        Binding(
            get: { MascotSize.closest(to: preferences.mascotScale) },
            set: { preferences.mascotScale = $0.scale }
        )
    }
}

private struct MascotMotion: ViewModifier {
    let mood: MascotMood
    @State private var animate = false

    func body(content: Content) -> some View {
        content
            // Attention moods shake; working bobs as if typing; happy springs up; idle breathes.
            .rotationEffect(.degrees(isAttention ? (animate ? 9 : -9) : 0))
            .offset(y: yOffset)
            .scaleEffect(mood == .idle ? (animate ? 1.04 : 0.97) : 1)
            .opacity(mood == .idle ? (animate ? 0.6 : 1.0) : 1.0)
            .animation(animation(for: mood), value: animate)
            .onAppear { animate = true }
            .onChange(of: mood) { _, _ in
                animate = false
                DispatchQueue.main.async { animate = true }
            }
    }

    private var isAttention: Bool {
        mood == .asking || mood == .permission || mood == .alert
    }

    private var yOffset: CGFloat {
        switch mood {
        case .happy: return animate ? -7 : 0
        case .working: return animate ? -3 : 3   // small continuous bob
        default: return 0
        }
    }

    private func animation(for mood: MascotMood) -> Animation {
        switch mood {
        case .asking, .permission, .alert:
            return .easeInOut(duration: 0.25).repeatForever(autoreverses: true)
        case .happy:
            return .interpolatingSpring(stiffness: 200, damping: 6).repeatCount(4, autoreverses: true)
        case .working:
            return .easeInOut(duration: 0.45).repeatForever(autoreverses: true)
        case .idle:
            return .easeInOut(duration: 2.4).repeatForever(autoreverses: true)
        }
    }
}
