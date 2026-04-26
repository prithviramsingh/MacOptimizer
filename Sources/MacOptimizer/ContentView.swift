import SwiftUI
import AppKit

enum NavItem: String, CaseIterable, Identifiable {
    case dashboard  = "Dashboard"
    case processes  = "Processes"
    case cleanup    = "Cleanup"
    case startup    = "Startup Items"
    case suggestions = "Suggestions"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:   return "gauge.medium"
        case .processes:   return "cpu"
        case .cleanup:     return "trash"
        case .startup:     return "play.circle"
        case .suggestions: return "lightbulb"
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                
                let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
                for buttonType in buttons {
                    if let button = window.standardWindowButton(buttonType) {
                        button.isHidden = true
                        button.alphaValue = 0
                        button.isEnabled = false
                    }
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct ContentView: View {
    @Environment(\.themeColors) private var colors
    @EnvironmentObject private var processMonitor: ProcessMonitor
    @EnvironmentObject private var knowledgeBase: KnowledgeBase

    @State private var selectedItem: NavItem = .dashboard

    var body: some View {
        HSplitView {
            SidebarView(selectedItem: $selectedItem)

            VStack(spacing: 0) {
                // Toolbar strip
                toolbarBar

                Rectangle()
                    .fill(colors.ink8)
                    .frame(height: 1)

                // Detail - Layered for performance
                ZStack {
                    DashboardView()
                        .opacity(selectedItem == .dashboard ? 1 : 0)
                        .disabled(selectedItem != .dashboard)
                    
                    ProcessesView()
                        .opacity(selectedItem == .processes ? 1 : 0)
                        .disabled(selectedItem != .processes)
                    
                    CleanupView()
                        .opacity(selectedItem == .cleanup ? 1 : 0)
                        .disabled(selectedItem != .cleanup)
                    
                    StartupItemsView()
                        .opacity(selectedItem == .startup ? 1 : 0)
                        .disabled(selectedItem != .startup)
                    
                    SuggestionsView()
                        .opacity(selectedItem == .suggestions ? 1 : 0)
                        .disabled(selectedItem != .suggestions)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(colors.paper)
            }
        }
        .background(colors.paper)
        .background(WindowAccessor())
        .onAppear {
            processMonitor.startMonitoring(knowledgeBase: knowledgeBase)
        }
    }

    // MARK: - Toolbar

    private var toolbarBar: some View {
        HStack {
            Text(selectedItem.rawValue)
                .font(AppFont.ui(12.5, weight: .semibold))
                .foregroundStyle(colors.ink)
            Spacer()
        }
        .padding(.horizontal, DS.Space.lg)
        .frame(height: DS.Size.toolbarHeight)
        .background(colors.surface)
    }
}
