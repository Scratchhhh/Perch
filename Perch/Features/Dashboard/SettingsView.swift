import SwiftUI
import PerchCore

struct SettingsView: View {
    @Environment(EventBus.self) private var bus
    @Environment(IntegrationsModel.self) private var integrations
    @Environment(PreferencesStore.self) private var preferences

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        @Bindable var bus = bus
        @Bindable var preferences = preferences

        Form {
            IntegrationsSection()

            Section("Notifications") {
                Toggle("Do Not Disturb", isOn: $bus.doNotDisturb)
                Toggle("Play sounds", isOn: $preferences.soundsEnabled)

                Toggle("Quiet hours", isOn: $preferences.dndScheduleEnabled)
                if preferences.dndScheduleEnabled {
                    DatePicker("From", selection: timeBinding(\.dndStartMinute), displayedComponents: .hourAndMinute)
                    DatePicker("Until", selection: timeBinding(\.dndEndMinute), displayedComponents: .hourAndMinute)
                }
            }

            Section("Mascot") {
                Toggle("Show the perch bird", isOn: $preferences.mascotEnabled)
                Text("A small, draggable companion that reacts to your agents. Drag it anywhere; click to open the dashboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: launchBinding)
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Channels") {
                LabeledContent("MCP — perch_notify", value: "Active")
                LabeledContent("Hooks — Claude Code", value: "Active")
                LabeledContent("File watch — transcripts", value: "Active")
            }

            Section("Coming soon") {
                LabeledContent("Telegram", value: "Planned")
                LabeledContent("ntfy", value: "Planned")
                Text("Remote notifiers will plug into the same event bus. Nothing leaves your Mac today.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Label("Everything stays on this Mac", systemImage: "lock.shield")
                Text("Perch talks only to 127.0.0.1 and ships zero telemetry. No account, no network calls beyond localhost.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
            }

            #if DEBUG
            Section("Developer") {
                Button("Send test \"done\" event") {
                    bus.ingest(Self.sample(kind: .finished))
                }
                Button("Send test \"needs you\" event") {
                    bus.ingest(Self.sample(kind: .permission))
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { integrations.refresh() }
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    try LoginItem.setEnabled(newValue)
                    launchAtLogin = newValue
                    loginError = nil
                } catch {
                    loginError = "Couldn't update login item: \(error.localizedDescription)"
                    launchAtLogin = LoginItem.isEnabled
                }
            }
        )
    }

    private func timeBinding(_ keyPath: ReferenceWritableKeyPath<PreferencesStore, Int>) -> Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: preferences[keyPath: keyPath]) },
            set: { preferences[keyPath: keyPath] = Self.minutes(from: $0) }
        )
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minutes / 60,
            minute: minutes % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    #if DEBUG
    private static func sample(kind: EventKind) -> RelayMessage {
        RelayMessage(
            sessionId: "preview-\(UUID().uuidString.prefix(8))",
            source: .claudeCode,
            channel: .test,
            kind: kind,
            message: kind == .finished ? "Refactored the auth layer and tests pass." : "Allow running `git push`?",
            project: "/Users/Shared/Demo Project"
        )
    }
    #endif
}
