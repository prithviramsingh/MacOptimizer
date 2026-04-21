import SwiftUI

enum NavItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case processes = "Processes"
    case cleanup = "Cleanup"
    case startup = "Startup Items"
    case suggestions = "Suggestions"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .processes: return "cpu"
        case .cleanup: return "trash"
        case .startup: return "play.circle"
        case .suggestions: return "lightbulb"
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: NavItem = .dashboard
    @EnvironmentObject private var processMonitor: ProcessMonitor

    var body: some View {
        NavigationSplitView {
            List(NavItem.allCases, selection: $selectedItem) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("Mac Optimizer")
        } detail: {
            switch selectedItem {
            case .dashboard:  DashboardView()
            case .processes:  ProcessesView()
            case .cleanup:    CleanupView()
            case .startup:    StartupItemsView()
            case .suggestions: SuggestionsView()
            }
        }
        .onAppear {
            processMonitor.startMonitoring()
        }
    }
}
