import SwiftUI

@main
struct MacOptimizerApp: App {
    @StateObject private var processMonitor = ProcessMonitor()
    @StateObject private var systemCleaner = SystemCleaner()
    @StateObject private var startupService = StartupItemsService()
    @StateObject private var knowledgeBase = KnowledgeBase()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(processMonitor)
                .environmentObject(systemCleaner)
                .environmentObject(startupService)
                .environmentObject(knowledgeBase)
                .frame(minWidth: 920, minHeight: 620)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
