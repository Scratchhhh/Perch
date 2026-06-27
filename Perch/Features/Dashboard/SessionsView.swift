import SwiftUI
import SwiftData
import AppKit
import PerchCore

struct SessionsView: View {
    @Environment(EventBus.self) private var bus
    @Query(sort: \AgentSession.lastActivityAt, order: .reverse)
    private var sessions: [AgentSession]

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "bird",
                    description: Text("Once an agent reports in, its session shows up here.")
                )
            } else {
                List {
                    ForEach(sessions) { session in
                        SessionRow(session: session, bus: bus)
                    }
                }
                .listStyle(.inset)
                .animation(.smooth(duration: 0.3), value: sessions.map(\.id))
            }
        }
        .navigationTitle("Sessions")
    }
}

private struct SessionRow: View {
    let session: AgentSession
    let bus: EventBus

    @State private var now = Date()
    @State private var turnStats: TurnStats?
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var isStuck: Bool { bus.stuckSessionIds.contains(session.id) }

    var body: some View {
        HStack(spacing: 12) {
            SessionStateIcon(state: session.state)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.label)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(session.source.displayName)
                    if let path = session.projectPath, !path.isEmpty {
                        Text("·")
                        Text(path)
                            .truncationMode(.middle)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if session.state == .working, let median = turnStats?.median {
                    Label("usually ~\(Self.durationText(median))", systemImage: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if isStuck {
                    Label("Possibly stuck — no update in a while", systemImage: "questionmark.diamond.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
                if session.isSnoozed(at: now), let until = session.snoozedUntil {
                    Label("Snoozed until \(until, format: .dateTime.hour().minute())", systemImage: "bell.slash.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(session.state.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(color(for: session.state))
                Text(session.lastActivityAt, format: .relative(presentation: .numeric))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            snoozeMenu

            if let path = session.projectPath, !path.isEmpty {
                Button {
                    NotificationRouter.shared.focusProject(path)
                } label: {
                    Image(systemName: "terminal")
                }
                .buttonStyle(.borderless)
                .help("Open project in Terminal so you can reply")

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .help("Reveal project in Finder")
            }
        }
        .padding(.vertical, 4)
        .onReceive(ticker) { now = $0 }
        .task(id: session.events.count) {
            turnStats = TurnEstimator.turnStats(eventTimes: session.events.map(\.ts))
        }
    }

    private var snoozeMenu: some View {
        Menu {
            if session.isSnoozed(at: now) {
                Button("Resume notifications") { bus.snooze(session, until: nil) }
            } else {
                Button("Snooze 15 minutes") { bus.snooze(session, until: Date().addingTimeInterval(15 * 60)) }
                Button("Snooze 1 hour") { bus.snooze(session, until: Date().addingTimeInterval(60 * 60)) }
            }
        } label: {
            Image(systemName: session.isSnoozed(at: now) ? "bell.slash.fill" : "bell")
                .foregroundStyle(session.isSnoozed(at: now) ? .orange : .secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(session.isSnoozed(at: now) ? "Snoozed — tap to resume" : "Snooze this session")
    }

    private func color(for state: SessionState) -> Color {
        switch state {
        case .working: return .blue
        case .waiting: return .orange
        case .done: return .green
        case .idle: return .secondary
        }
    }

    private static func durationText(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 1 { return "\(Int(seconds.rounded()))s" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}
