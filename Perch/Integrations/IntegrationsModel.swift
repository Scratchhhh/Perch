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

    /// On launch, bring any already-connected-but-outdated integration up to date (e.g. an older
    /// hook set missing PermissionRequest). Only touches integrations that are partially present,
    /// so tools the user never connected are left alone. Idempotent and backed up.
    func repairOutdated() {
        for integration in integrations where integration.refreshStatus() == .partiallyInstalled {
            do {
                _ = try integration.install()
                PerchLog.integration.info("auto-repaired \(integration.id, privacy: .public)")
            } catch {
                PerchLog.integration.error("auto-repair failed for \(integration.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        refresh()
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
