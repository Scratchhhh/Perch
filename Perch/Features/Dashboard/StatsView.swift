import SwiftUI
import SwiftData
import Charts
import PerchCore

struct StatsView: View {
    @Query(sort: \AgentEvent.ts) private var events: [AgentEvent]

    private var summary: StatsSummary {
        let stats = events.map {
            EventStat(timestamp: $0.ts, acknowledgedAt: $0.acknowledgedAt, isNotable: $0.isNotable)
        }
        return StatsCalculator.summarize(stats, now: Date())
    }

    var body: some View {
        let summary = summary

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    StatCard(
                        title: "Waiting saved",
                        value: formatted(minutes: summary.savedMinutes),
                        systemImage: "clock.badge.checkmark",
                        tint: .green
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

                if events.isEmpty {
                    Text("Once your agents start reporting in, your saved-waiting time and streak show up here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .animation(.smooth(duration: 0.35), value: summary.totalNotable)
        }
        .navigationTitle("Stats")
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
