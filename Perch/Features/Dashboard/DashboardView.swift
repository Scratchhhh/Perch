import SwiftUI
import Observation

enum DashboardTab: String, CaseIterable, Identifiable {
    case sessions
    case history
    case stats
    case settings
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sessions: return "Sessions"
        case .history: return "History"
        case .stats: return "Stats"
        case .settings: return "Settings"
        case .logs: return "Logs"
        }
    }

    var systemImage: String {
        switch self {
        case .sessions: return "list.bullet.rectangle"
        case .history: return "clock.arrow.circlepath"
        case .stats: return "chart.bar"
        case .settings: return "gearshape"
        case .logs: return "doc.text.magnifyingglass"
        }
    }
}

@MainActor
@Observable
final class DashboardNavigation {
    static let shared = DashboardNavigation()
    var selection: DashboardTab = .sessions
    private init() {}
}

struct DashboardView: View {
    @Bindable private var navigation = DashboardNavigation.shared
    @Environment(EventBus.self) private var bus

    var body: some View {
        TabView(selection: $navigation.selection) {
            ForEach(DashboardTab.allCases) { tab in
                tabContent(tab)
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .task { bus.acknowledge() }
    }

    @ViewBuilder
    private func tabContent(_ tab: DashboardTab) -> some View {
        switch tab {
        case .sessions: SessionsView()
        case .history: HistoryView()
        case .stats: StatsView()
        case .settings: SettingsView()
        case .logs: LogsView()
        }
    }
}
