import SwiftUI
import SwiftData
import PerchCore

struct HistoryView: View {
    static let pageSize = 200

    @State private var searchText = ""
    @State private var limit = HistoryView.pageSize

    var body: some View {
        HistoryList(searchText: searchText, limit: limit) {
            limit += Self.pageSize
        }
        .searchable(text: $searchText, prompt: "Search history")
        .onChange(of: searchText) { _, _ in limit = Self.pageSize }
        .navigationTitle("History")
    }
}

/// The fetch lives in a child whose `@Query` is rebuilt from the search text and page limit. This
/// keeps the database doing the filtering and paging (predicate + `fetchLimit`) instead of loading
/// every event into memory and scanning it on each render. The `session` relationship is
/// prefetched so rendering rows doesn't trigger a fault (and an extra query) per visible row.
private struct HistoryList: View {
    @Query private var events: [AgentEvent]
    private let searchText: String
    private let limit: Int
    private let onLoadMore: () -> Void

    init(searchText: String, limit: Int, onLoadMore: @escaping () -> Void) {
        self.searchText = searchText
        self.limit = limit
        self.onLoadMore = onLoadMore

        var descriptor = FetchDescriptor<AgentEvent>(
            predicate: #Predicate { event in
                searchText.isEmpty
                    || event.message.localizedStandardContains(searchText)
                    || (event.session?.label.localizedStandardContains(searchText) ?? false)
            },
            sortBy: [SortDescriptor(\.ts, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.relationshipKeyPathsForPrefetching = [\.session]
        _events = Query(descriptor)
    }

    var body: some View {
        if events.isEmpty {
            if searchText.isEmpty {
                ContentUnavailableView(
                    "Nothing logged yet",
                    systemImage: "clock",
                    description: Text("Past events from your agents will appear here.")
                )
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        } else {
            List {
                ForEach(events) { event in
                    HistoryRow(event: event)
                }
                if events.count >= limit {
                    Button(action: onLoadMore) {
                        Text("Load more")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
            .animation(.smooth(duration: 0.3), value: events.count)
        }
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
