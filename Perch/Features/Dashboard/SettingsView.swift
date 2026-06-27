import SwiftUI
import SwiftData
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

            ProjectRulesSection()

            Section("Mascot") {
                Toggle("Show the perch bird", isOn: $preferences.mascotEnabled)
                if preferences.mascotEnabled {
                    Picker("Size", selection: mascotSizeBinding) {
                        ForEach(MascotSize.allCases) { size in
                            Text(size.label).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
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
                LabeledContent("MCP: perch_notify", value: "Active")
                LabeledContent("Hooks: Claude Code", value: "Active")
                LabeledContent("File watch: transcripts", value: "Active")
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
                Button("Seed 1,200 demo events") {
                    bus.seedDemoEvents()
                }
                Button("Delete all data", role: .destructive) {
                    bus.deleteAllData()
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .animation(.smooth(duration: 0.25), value: preferences.dndScheduleEnabled)
        .animation(.smooth(duration: 0.25), value: loginError)
        .task { integrations.refresh() }
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }

    private var mascotSizeBinding: Binding<MascotSize> {
        Binding(
            get: { MascotSize.closest(to: preferences.mascotScale) },
            set: { preferences.mascotScale = $0.scale }
        )
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

/// Lists every project Perch has seen and lets the user override banner/sound delivery per project.
/// Only appears once at least one project-scoped session exists.
private struct ProjectRulesSection: View {
    @Environment(PreferencesStore.self) private var preferences
    @Query(sort: \AgentSession.lastActivityAt, order: .reverse) private var sessions: [AgentSession]

    private var projects: [(path: String, name: String)] {
        var seen = Set<String>()
        var result: [(String, String)] = []
        for session in sessions {
            guard let path = session.projectPath, !path.isEmpty, seen.insert(path).inserted else { continue }
            result.append((path, session.label))
        }
        return result
    }

    var body: some View {
        if !projects.isEmpty {
            Section("Per-project rules") {
                ForEach(projects, id: \.path) { project in
                    let binding = ruleBinding(for: project.path)
                    DisclosureGroup {
                        Toggle("Show banners", isOn: binding.bannerEnabled)
                        Toggle("Play sound", isOn: binding.soundEnabled)
                            .disabled(!binding.wrappedValue.bannerEnabled)
                        HStack {
                            Text("Volume")
                            Slider(value: binding.volume, in: 0...1)
                        }
                        .disabled(!binding.wrappedValue.bannerEnabled || !binding.wrappedValue.soundEnabled)
                    } label: {
                        HStack {
                            Text(project.name)
                            Spacer()
                            Text(summary(binding.wrappedValue))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Turning banners off mutes a project entirely; with banners on you can still silence or quieten its sound.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summary(_ rule: ProjectRule) -> String {
        if !rule.bannerEnabled { return "Muted" }
        if !rule.soundEnabled { return "Silent" }
        return "On · \(Int(rule.volume * 100))%"
    }

    private func ruleBinding(for path: String) -> Binding<ProjectRule> {
        Binding(
            get: { preferences.rule(for: path) },
            set: { preferences.projectRules[path] = $0 }
        )
    }
}
