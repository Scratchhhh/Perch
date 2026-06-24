import SwiftUI
import SwiftData
import PerchCore

struct HistoryView: View {
    @Query(sort: \AgentEvent.ts, order: .reverse)
    private var events: [AgentEvent]

    @State private var searchText = ""

    private var filtered: [AgentEvent] {
        guard !searchText.isEmpty else { return events }
        return events.filter { event in
            event.message.localizedCaseInsensitiveContains(searchText)
                || (event.session?.label.localizedCaseInsensitiveContains(searchText) ?? false)
                || event.source.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if events.isEmpty {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "clock",
                    description: Text("Past events from your agents will appear here.")
                )
            } else {
                List(filtered) { event in
                    HistoryRow(event: event)
                }
                .listStyle(.inset)
                .searchable(text: $searchText, prompt: "Search history")
            }
        }
        .navigationTitle("History")
    }
}

private struct HistoryRow: View {
    let event: AgentEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.session?.label ?? event.source.displayName)
                    .font(.callout.weight(.medium))
                if !event.message.isEmpty {
                    Text(event.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(event.kind.rawValue)
                    .font(.caption2.weight(.medium))
                Text(event.channel.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(event.ts, format: .dateTime.hour().minute().day().month())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private var icon: String {
        switch event.kind {
        case .finished: return "checkmark.circle.fill"
        case .needsInput, .permission, .blocked: return "exclamationmark.circle.fill"
        case .started: return "play.circle.fill"
        case .subagentDone: return "arrow.triangle.branch"
        }
    }

    private var tint: Color {
        switch event.kind {
        case .finished: return .green
        case .needsInput, .permission, .blocked: return .orange
        case .started, .subagentDone: return .blue
        }
    }
}
