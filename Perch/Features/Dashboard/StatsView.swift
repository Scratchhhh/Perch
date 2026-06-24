import SwiftUI
import SwiftData
import PerchCore

struct StatsView: View {
    @Query private var sessions: [AgentSession]
    @Query private var events: [AgentEvent]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Overview")
                    .font(.title3.weight(.semibold))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    StatCard(title: "Sessions", value: "\(sessions.count)", systemImage: "list.bullet.rectangle", tint: .blue)
                    StatCard(title: "Events", value: "\(events.count)", systemImage: "bolt", tint: .purple)
                    StatCard(title: "Working", value: "\(count(.working))", systemImage: "gearshape.2", tint: .blue)
                    StatCard(title: "Waiting", value: "\(count(.waiting))", systemImage: "exclamationmark.circle", tint: .orange)
                }
            }
            .padding(20)
        }
        .navigationTitle("Stats")
    }

    private func count(_ state: SessionState) -> Int {
        sessions.filter { $0.state == state }.count
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
