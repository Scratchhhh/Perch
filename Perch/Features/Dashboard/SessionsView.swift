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
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

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
}
