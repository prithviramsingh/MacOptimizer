import SwiftUI
import AppKit

private func makeAppIcon() -> NSImage {
    let size = CGSize(width: 512, height: 512)
    return NSImage(size: size, flipped: false) { rect in
        let inset = rect.insetBy(dx: 16, dy: 16)
        let path = NSBezierPath(roundedRect: inset, xRadius: 110, yRadius: 110)
        NSGradient(colors: [
            NSColor(red: 0.40, green: 0.28, blue: 0.96, alpha: 1),
            NSColor(red: 0.65, green: 0.33, blue: 0.97, alpha: 1)
        ])?.draw(in: path, angle: -45)

        let symSize: CGFloat = 270
        let symRect = NSRect(x: (rect.width - symSize) / 2,
                             y: (rect.height - symSize) / 2,
                             width: symSize, height: symSize)
        if let sym = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 240, weight: .bold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
            (sym.withSymbolConfiguration(cfg) ?? sym).draw(in: symRect)
        }
        return true
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct MacOptimizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var processMonitor = ProcessMonitor()
    @StateObject private var systemCleaner  = SystemCleaner()
    @StateObject private var startupService = StartupItemsService()
    @StateObject private var knowledgeBase  = KnowledgeBase()
    @StateObject private var themeManager   = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { NSApp.applicationIconImage = makeAppIcon() }
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
