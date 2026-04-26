import SwiftUI

struct StartupItemsView: View {
    @Environment(\.themeColors) private var colors
    @EnvironmentObject private var startupService: StartupItemsService

    @State private var scopeFilter: ScopeFilter = .all

    enum ScopeFilter: String, CaseIterable {
        case all = "All", user = "User", system = "System"
    }

    // MARK: - Derived

    private var enabledCount: Int { startupService.items.filter(\.isEnabled).count }

    private var displayed: [StartupItem] {
        switch scopeFilter {
        case .all:    return startupService.items
        case .user:   return startupService.items.filter { $0.source == .launchAgent }
        case .system: return startupService.items.filter { $0.source == .launchDaemon }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {

                // Header
                headerSection

                // Items
                if startupService.isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(DS.Space.xxl)
                } else if startupService.items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .padding(DS.Space.xl)
        }
        .background(Color.clear)
        .onAppear {
            if startupService.items.isEmpty {
                Task { await startupService.load() }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DSEyebrow("Startup Items")

            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%d", enabledCount))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(colors.accent)
                    .italic()
                Text(String(format: " of %d launch at login", startupService.items.count))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(colors.ink)
                Spacer()
                DSBtn("Refresh", variant: .ghost, small: true) {
                    Task { await startupService.load() }
                }
            }

            Text("Disabling items you don't need reduces login time and frees background resources.")
                .font(AppFont.bodyUI)
                .foregroundStyle(colors.ink50)

            // Scope filter
            HStack(spacing: 2) {
                ForEach(ScopeFilter.allCases, id: \.self) { f in
                    scopeTab(f)
                }
            }
            .padding(3)
            .background(colors.ink8)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .frame(alignment: .leading)
        }
    }

    private func scopeTab(_ f: ScopeFilter) -> some View {
        let active = scopeFilter == f
        return Button {
            withAnimation(.easeInOut(duration: 0.14)) { scopeFilter = f }
        } label: {
            Text(f.rawValue)
                .font(AppFont.ui(12, weight: .semibold))
                .foregroundStyle(active ? colors.ink : colors.ink50)
                .padding(.horizontal, DS.Space.sm + 2)
                .padding(.vertical, 5)
                .background(active ? colors.surface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        DSCard(padding: DS.Space.xxl) {
            VStack(spacing: DS.Space.sm) {
                Image(systemName: "play.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(colors.ink20)
                Text("No startup items found")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(colors.ink)
                Text("You may need to grant Full Disk Access to read launch agents.")
                    .font(AppFont.bodyUI)
                    .foregroundStyle(colors.ink50)
                    .multilineTextAlignment(.center)
                DSBtn("Load Items", variant: .primary, small: true) {
                    Task { await startupService.load() }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Item List

    private var itemList: some View {
        DSCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(displayed.enumerated()), id: \.element.id) { idx, item in
                    startupItemRow(item)
                    if idx < displayed.count - 1 {
                        Divider().padding(.leading, DS.Space.lg).opacity(0.4)
                    }
                }
            }
        }
    }

    private func startupItemRow(_ item: StartupItem) -> some View {
        HStack(spacing: DS.Space.md) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.icon, style: .continuous)
                    .fill(item.isEnabled ? colors.accent10 : colors.ink5)
                    .frame(width: 36, height: 36)
                Image(systemName: "play.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(item.isEnabled ? colors.accentStrong : colors.ink30)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DS.Space.xs) {
                    Text(item.label)
                        .font(AppFont.monoCaption)
                        .foregroundStyle(colors.ink)
                        .lineLimit(1)
                    DSChip(item.source.rawValue, tone: item.source == .launchDaemon ? .neutral : .accent)
                }
                Text(item.path)
                    .font(AppFont.monoCaption)
                    .foregroundStyle(colors.ink40)
                    .lineLimit(1)
                Text(item.isEnabled ? "Enabled — launches at login" : "Disabled")
                    .font(AppFont.captionUI)
                    .foregroundStyle(item.isEnabled ? colors.good : colors.ink40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Toggle
            Toggle("", isOn: Binding(
                get:  { item.isEnabled },
                set:  { _ in Task { await startupService.toggle(item) } }
            ))
            .toggleStyle(DSToggleStyle())
            .labelsHidden()
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm + 2)
    }
}
