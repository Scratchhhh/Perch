import SwiftUI
import SwiftData
import AppKit
import PerchCore

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(EventBus.self) private var bus

    @Query(
        filter: #Predicate<AgentSession> { $0.stateRaw == "working" || $0.stateRaw == "waiting" },
        sort: \AgentSession.lastActivityAt,
        order: .reverse
    )
    private var activeSessions: [AgentSession]

    var body: some View {
        @Bindable var bus = bus

        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if activeSessions.isEmpty {
                emptyState
            } else {
                sessionList
            }

            Divider()

            Toggle(isOn: $bus.doNotDisturb) {
                Label("Do Not Disturb", systemImage: bus.doNotDisturb ? "moon.fill" : "moon")
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            actions
        }
        .frame(width: 320)
        .task {
            wireNavigation()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bird.fill")
                .foregroundStyle(.tint)
            Text("Perch")
                .font(.headline)
            Spacer()
            if bus.waitingCount > 0 {
                Text("\(bus.waitingCount) waiting")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if bus.workingCount > 0 {
                Text("\(bus.workingCount) working")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "bird")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("All quiet on the perch")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 18)
    }

    private var sessionList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(activeSessions) { session in
                    MenuSessionRow(session: session) {
                        openProject(session)
                    }
                    if session != activeSessions.last {
                        Divider().padding(.leading, 40)
                    }
                }
            }
        }
        .frame(maxHeight: 260)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            MenuActionButton(title: "Open Dashboard", systemImage: "macwindow") {
                openDashboard()
            }
            MenuActionButton(title: "Settings", systemImage: "gearshape") {
                openDashboard(tab: .settings)
            }
            MenuActionButton(title: "Quit Perch", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 4)
    }

    private func wireNavigation() {
        WindowOpener.shared.open = { id in
            openWindow(id: id)
        }
        NotificationRouter.shared.onOpenDashboard = {
            WindowOpener.shared.focus()
        }
        NotificationRouter.shared.onOpenProject = { path in
            NotificationRouter.shared.revealProject(path)
            NSApplication.shared.activate()
        }
    }

    private func openDashboard(tab: DashboardTab? = nil) {
        if let tab {
            DashboardNavigation.shared.selection = tab
        }
        WindowOpener.shared.focus()
    }

    private func openProject(_ session: AgentSession) {
        if let path = session.projectPath, !path.isEmpty {
            NotificationRouter.shared.revealProject(path)
            NSApplication.shared.activate()
        } else {
            openDashboard()
        }
    }
}

private struct MenuSessionRow: View {
    let session: AgentSession
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SessionStateIcon(state: session.state)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.label)
                    .font(.callout)
                    .lineLimit(1)
                Text("\(session.source.displayName) · \(session.lastActivityAt, format: .relative(presentation: .numeric))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onOpen) {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .help("Reveal project in Finder")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct MenuActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .background(hovering ? Color.primary.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
