import SwiftUI
import AppKit

// MARK: - Window Accessor (hide native traffic lights so custom ones render)

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum NavItem: String, CaseIterable, Identifiable {
    case dashboard   = "Dashboard"
    case processes   = "Processes"
    case cleanup     = "Cleanup"
    case startup     = "Startup Items"
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

// MARK: - Traffic Lights

struct TrafficLightsView: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: 0xFF5F57)).frame(width: 12, height: 12)
            Circle().fill(Color(hex: 0xFEBC2E)).frame(width: 12, height: 12)
            Circle().fill(Color(hex: 0x28C840)).frame(width: 12, height: 12)
        }
    }
}

// MARK: - Top Tabs with glass pill

struct TopTabsView: View {
    @Environment(\.themeColors) private var colors
    @EnvironmentObject private var processMonitor: ProcessMonitor
    @EnvironmentObject private var knowledgeBase: KnowledgeBase

    @Binding var selectedItem: NavItem
    let namespace: Namespace.ID

    private var hogCount: Int { processMonitor.resourceHogs.count }
    private var suggCount: Int { knowledgeBase.suggestions.count }
    private var critCount: Int { knowledgeBase.suggestions.filter { $0.severity == .critical }.count }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(NavItem.allCases) { item in
                tabButton(item)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func tabButton(_ item: NavItem) -> some View {
        let isSelected = selectedItem == item
        let badge: Int? = {
            switch item {
            case .processes:   return hogCount > 0 ? hogCount : nil
            case .suggestions: return suggCount > 0 ? suggCount : nil
            default:           return nil
            }
        }()
        let isCrit = item == .suggestions && critCount > 0

        return Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                selectedItem = item
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .medium))
                Text(item == .startup ? "Startup" : item.rawValue)
                    .font(.system(size: 12.5, weight: .semibold))
                if let b = badge {
                    Text("\(b)")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(isCrit ? colors.critical : colors.accent)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? colors.ink : colors.ink60)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                        .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 1)
                        .matchedGeometryEffect(id: "tabPill", in: namespace)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Aurora background

struct AuroraBackground: View {
    let aurora: AuroraColors

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [aurora.base1, aurora.base2],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [aurora.blob1, .clear],
                    center: .init(x: 0.12, y: 0.10),
                    startRadius: 0, endRadius: geo.size.width * 0.55
                )
                RadialGradient(
                    colors: [aurora.blob2, .clear],
                    center: .init(x: 0.92, y: 0.18),
                    startRadius: 0, endRadius: geo.size.width * 0.50
                )
                RadialGradient(
                    colors: [aurora.blob3, .clear],
                    center: .init(x: 0.88, y: 0.88),
                    startRadius: 0, endRadius: geo.size.width * 0.48
                )
                RadialGradient(
                    colors: [aurora.blob4, .clear],
                    center: .init(x: 0.10, y: 0.92),
                    startRadius: 0, endRadius: geo.size.width * 0.55
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(\.themeColors) private var colors
    @EnvironmentObject private var processMonitor: ProcessMonitor
    @EnvironmentObject private var knowledgeBase: KnowledgeBase
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var selectedItem: NavItem = .dashboard
    @State private var jumpToProcess: ProcessSnapshot? = nil
    @State private var jumpToSuggestion: Suggestion? = nil
    @Namespace private var tabNamespace

    var body: some View {
        ZStack {
            AuroraBackground(aurora: colors.aurora)

            VStack(spacing: 0) {
                glassToolbar
                Divider()
                    .background(Color.white.opacity(0.4))
                contentArea
            }
        }
        .background(WindowAccessor())
        .onAppear {
            processMonitor.startMonitoring(knowledgeBase: knowledgeBase)
        }
        .onChange(of: jumpToProcess) { process in
            guard process != nil else { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                selectedItem = .processes
            }
        }
    }

    // MARK: - Glass Toolbar

    private var glassToolbar: some View {
        HStack(spacing: 12) {
            // Brand
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(LinearGradient(
                            colors: [colors.accent, Color(hex: 0xA855F7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 24, height: 24)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("MacOptimizer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(colors.ink)
            }

            Spacer()

            TopTabsView(selectedItem: $selectedItem, namespace: tabNamespace)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    themeManager.toggle()
                }
            } label: {
                Image(systemName: themeManager.currentTheme == .light ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.ink50)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.20))
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        ZStack {
            DashboardView(selectedItem: $selectedItem, jumpToProcess: $jumpToProcess, jumpToSuggestion: $jumpToSuggestion)
                .opacity(selectedItem == .dashboard ? 1 : 0)
                .allowsHitTesting(selectedItem == .dashboard)

            ProcessesView(jumpToProcess: $jumpToProcess)
                .opacity(selectedItem == .processes ? 1 : 0)
                .allowsHitTesting(selectedItem == .processes)

            CleanupView()
                .opacity(selectedItem == .cleanup ? 1 : 0)
                .allowsHitTesting(selectedItem == .cleanup)

            StartupItemsView()
                .opacity(selectedItem == .startup ? 1 : 0)
                .allowsHitTesting(selectedItem == .startup)

            SuggestionsView(jumpToSuggestion: $jumpToSuggestion, jumpToProcess: $jumpToProcess)
                .opacity(selectedItem == .suggestions ? 1 : 0)
                .allowsHitTesting(selectedItem == .suggestions)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
