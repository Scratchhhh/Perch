import SwiftUI
import SwiftData
import Charts
import PerchCore

struct StatsView: View {
    @Query(sort: \AgentEvent.ts) private var events: [AgentEvent]

    /// Computed off the render path (see `recompute`) so switching to this tab with thousands of
    /// events in the store doesn't run the whole aggregation inside `body`.
    @State private var summary = StatsSummary(
        focusSavedMinutes: 0, contextSwitchesAvoided: 0, streakDays: 0, totalNotable: 0, perDay: []
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    StatCard(
                        title: "Focus saved",
                        value: formatted(minutes: summary.focusSavedMinutes),
                        systemImage: "brain.head.profile",
                        tint: .green
                    )
                    StatCard(
                        title: "Context switches avoided",
                        value: "\(summary.contextSwitchesAvoided)",
                        systemImage: "arrow.triangle.2.circlepath",
                        tint: .teal
                    )
                    StatCard(
                        title: "Day streak",
                        value: "\(summary.streakDays)",
                        systemImage: "flame.fill",
                        tint: .orange
                    )
                    StatCard(
                        title: "Notifications",
                        value: "\(summary.totalNotable)",
                        systemImage: "bell.badge.fill",
                        tint: .blue
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Last 14 days")
                        .font(.headline)
                    Chart(summary.perDay) { day in
                        BarMark(
                            x: .value("Day", day.day, unit: .day),
                            y: .value("Notifications", day.count)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(3)
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 3)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                }
                .padding(14)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))

                Text("Focus saved is the union of the time agents spent actually waiting on you — overlapping waits across parallel agents count once, not several times.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if events.isEmpty {
                    Text("Once your agents start reporting in, your saved focus time and streak show up here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .animation(.smooth(duration: 0.35), value: summary.totalNotable)
        }
        .navigationTitle("Stats")
        .task(id: events.count) { await recompute() }
    }

    /// Maps the stored events on the main actor (cheap property reads) then hands the `Sendable`
    /// snapshot to a background task for the heavy aggregation, assigning the result back on main.
    private func recompute() async {
        let stats = events.map {
            EventStat(
                timestamp: $0.ts,
                acknowledgedAt: $0.acknowledgedAt,
                isNotable: $0.isNotable,
                demandsAttention: $0.kind.demandsAttention
            )
        }
        let now = Date()
        let computed = await Task.detached(priority: .userInitiated) {
            StatsCalculator.summarize(stats, now: now)
        }.value
        summary = computed
    }

    private func formatted(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.title2)
            Text(value)
                .font(.title.weight(.bold))
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}
