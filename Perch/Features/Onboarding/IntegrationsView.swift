import SwiftUI
import AppKit

/// Renders as Form sections so it can live inside the Settings screen.
struct IntegrationsSection: View {
    @Environment(IntegrationsModel.self) private var model

    var body: some View {
        Section {
            ForEach(model.integrations, id: \.id) { integration in
                IntegrationRow(integration: integration)
            }
        } header: {
            Text("Integrations")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let message = model.lastMessage {
                    Label(message, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
                if let error = model.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                Text("Perch backs up each file before editing and only touches its own entries.")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
    }
}

private struct IntegrationRow: View {
    @Environment(IntegrationsModel.self) private var model
    let integration: any Integration

    @State private var showingDetails = false

    private var status: IntegrationStatus {
        model.status(for: integration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: integration.iconSystemName)
                    .font(.title3)
                    .frame(width: 26)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(integration.title)
                        .font(.body.weight(.medium))
                    Text(integration.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusPill(status: status)
                actionButton
            }

            DisclosureGroup(isExpanded: $showingDetails) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(integration.configURL.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text(integration.plannedChange)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.top, 4)
            } label: {
                Text("What changes")
                    .font(.caption)
            }

            if let snippet = integration.rulesSnippet {
                Button {
                    copy(snippet)
                } label: {
                    Label("Copy prompt snippet", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Optional: paste into your project rules so the agent calls perch_notify.")
            }
        }
        .padding(.vertical, 4)
    }

    private func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        model.lastMessage = "Prompt snippet copied to the clipboard."
        model.lastError = nil
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .installed:
            Button("Remove", role: .destructive) {
                model.uninstall(integration)
            }
        case .unavailable:
            Button("Connect") {}.disabled(true)
        case .notDetected, .notInstalled, .partiallyInstalled:
            Button(status == .partiallyInstalled ? "Repair" : "Connect") {
                model.install(integration)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct StatusPill: View {
    let status: IntegrationStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .installed: return .green
        case .partiallyInstalled: return .orange
        case .unavailable: return .red
        case .notDetected, .notInstalled: return .gray
        }
    }
}
