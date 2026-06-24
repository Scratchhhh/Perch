import SwiftUI

@main
struct PerchApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environment(environment.eventBus)
                .modelContainer(environment.modelContainer)
        } label: {
            MenuBarLabel(state: environment.menuBarState)
        }
        .menuBarExtraStyle(.window)

        Window("Perch", id: WindowOpener.dashboardID) {
            DashboardView()
                .environment(environment.eventBus)
                .environment(environment.integrations)
                .modelContainer(environment.modelContainer)
        }
        .defaultSize(width: 780, height: 540)
        .windowResizability(.contentSize)
    }
}
