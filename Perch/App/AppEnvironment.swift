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

    @ObservationIgnored private let localNotifier: LocalNotifier
    @ObservationIgnored private let listener: LocalListener

    init() {
        let container = AppEnvironment.makeContainer()
        self.modelContainer = container

        let notifier = LocalNotifier()
        self.localNotifier = notifier
        self.eventBus = EventBus(modelContext: container.mainContext, notifiers: [notifier])
        self.integrations = IntegrationsModel(integrations: [ClaudeCodeHooksIntegration()])

        let token = TokenStore.loadOrCreate()
        let bus = self.eventBus
        self.listener = LocalListener(token: token) { message in
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
