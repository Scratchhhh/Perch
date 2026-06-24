import Foundation
import Observation
import PerchCore

@MainActor
@Observable
final class IntegrationsModel {
    let integrations: [any Integration]

    private(set) var statuses: [String: IntegrationStatus] = [:]
    var lastMessage: String?
    var lastError: String?

    init(integrations: [any Integration]) {
        self.integrations = integrations
        refresh()
    }

    func status(for integration: any Integration) -> IntegrationStatus {
        statuses[integration.id] ?? .notInstalled
    }

    func refresh() {
        for integration in integrations {
            statuses[integration.id] = integration.refreshStatus()
        }
    }

    func install(_ integration: any Integration) {
        run(integration, verb: "Connected") { try integration.install() }
    }

    func uninstall(_ integration: any Integration) {
        run(integration, verb: "Disconnected") { try integration.uninstall() }
    }

    private func run(_ integration: any Integration, verb: String, action: () throws -> IntegrationActionResult) {
        do {
            let result = try action()
            if let backup = result.backupURL {
                lastMessage = "\(verb) \(integration.title). Backed up \(backup.lastPathComponent)."
            } else {
                lastMessage = "\(verb) \(integration.title)."
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            PerchLog.integration.error("\(integration.id, privacy: .public) action failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }
}
