import SwiftUI
import PerchCore

struct SettingsView: View {
    @Environment(EventBus.self) private var bus
    @Environment(IntegrationsModel.self) private var integrations

    var body: some View {
        @Bindable var bus = bus

        Form {
            IntegrationsSection()

            Section("Notifications") {
                Toggle("Do Not Disturb", isOn: $bus.doNotDisturb)
                Text("Pauses every banner without losing the underlying events.")
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
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
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
