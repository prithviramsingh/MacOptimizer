import SwiftUI

@main
struct MacOptimizerApp: App {
    @StateObject private var processMonitor = ProcessMonitor()
    @StateObject private var systemCleaner  = SystemCleaner()
    @StateObject private var startupService = StartupItemsService()
    @StateObject private var knowledgeBase  = KnowledgeBase()
    @StateObject private var themeManager   = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(processMonitor)
                .environmentObject(systemCleaner)
                .environmentObject(startupService)
                .environmentObject(knowledgeBase)
                .environmentObject(themeManager)
                .environment(\.processKnowledgeDB, knowledgeBase.db)
                .environment(\.themeColors, themeManager.colors)
                .preferredColorScheme(themeManager.colorScheme)
                .frame(minWidth: 920, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
