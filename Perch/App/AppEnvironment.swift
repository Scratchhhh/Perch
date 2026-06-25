import Foundation
import SwiftData
import Observation
import PerchCore

/// Owns the long-lived objects: the SwiftData store, the event bus, the notifiers and the
/// loopback listener. Created once and handed to the scenes.
@MainActor
@Observable
final class AppEnvironment {
    let modelContainer: ModelContainer
    let eventBus: EventBus
    let integrations: IntegrationsModel
    let preferences: PreferencesStore

    @ObservationIgnored private let localNotifier: LocalNotifier
    @ObservationIgnored private let listener: LocalListener
    @ObservationIgnored private let transcriptWatcher: TranscriptWatcher
    @ObservationIgnored private let mascot: MascotController

    init() {
        let container = AppEnvironment.makeContainer()
        self.modelContainer = container

        let preferences = PreferencesStore()
        self.preferences = preferences

        let notifier = LocalNotifier(preferences: preferences)
        self.localNotifier = notifier

        let bus = EventBus(modelContext: container.mainContext, preferences: preferences, notifiers: [notifier])
        self.eventBus = bus
        self.mascot = MascotController(eventBus: bus, preferences: preferences)
        self.integrations = IntegrationsModel(integrations: [
            ClaudeCodeIntegration(),
            CursorIntegration(),
            CodexIntegration()
        ])

        let token = TokenStore.loadOrCreate()
        self.listener = LocalListener(token: token) { message in
            Task { @MainActor in
                bus.ingest(message)
            }
        }
        self.transcriptWatcher = TranscriptWatcher { message in
            Task { @MainActor in
                bus.ingest(message)
            }
        }

        start()
    }

    var menuBarState: MenuBarState {
        eventBus.menuBarState
    }

    private func start() {
        localNotifier.requestAuthorization()
        do {
            try listener.start()
        } catch {
            PerchLog.listener.error("listener failed to start: \(error.localizedDescription, privacy: .public)")
        }
        transcriptWatcher.start()
        mascot.setVisible(preferences.mascotEnabled)
        observeMascotPreference()
        integrations.repairOutdated()
    }

    private func observeMascotPreference() {
        withObservationTracking {
            _ = preferences.mascotEnabled
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.mascot.setVisible(self.preferences.mascotEnabled)
                self.observeMascotPreference()
            }
        }
    }

    private static func makeContainer() -> ModelContainer {
        do {
            return try PerchModelContainer.make()
        } catch {
            PerchLog.app.error("persistent store unavailable, using memory: \(error.localizedDescription, privacy: .public)")
            do {
                return try PerchModelContainer.make(inMemory: true)
            } catch {
                preconditionFailure("unable to create any model container: \(error)")
            }
        }
    }
}
