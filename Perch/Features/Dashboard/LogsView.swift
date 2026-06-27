import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LogsView: View {
    @State private var lines: [LogLine] = []
    @State private var query = ""

    private var filtered: [LogLine] {
        guard !query.isEmpty else { return lines }
        return lines.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Filter", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                Spacer()
                Button { Task { await reload() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                Button { copy() } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .disabled(lines.isEmpty)
                Button { export() } label: { Label("Export…", systemImage: "square.and.arrow.up") }
                    .disabled(lines.isEmpty)
            }
            .padding(10)

            Divider()

            if filtered.isEmpty {
                ContentUnavailableView(
                    "No recent logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Perch's own log entries from this session appear here.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filtered) { line in
                            Text(line.text)
                                .font(.caption.monospaced())
                                .foregroundStyle(color(for: line.level))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .navigationTitle("Logs")
        .task { await reload() }
    }

    /// Reading the unified log store is synchronous and can stall; do it off the main thread and
    /// only hop back to assign the result.
    private func reload() async {
        let entries = await Task.detached(priority: .userInitiated) {
            LogExporter.recentEntries()
        }.value
        lines = entries
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(LogExporter.formatted(lines), forType: .string)
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "perch-log.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? Data(LogExporter.formatted(lines).utf8).write(to: url, options: .atomic)
    }

    private func color(for level: String) -> Color {
        switch level {
        case "error", "fault": return .red
        case "notice": return .primary
        default: return .secondary
        }
    }
}
