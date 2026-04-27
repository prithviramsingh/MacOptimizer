import SwiftUI

struct SidebarView: View {
    @Environment(\.themeColors) private var colors
    @EnvironmentObject private var processMonitor: ProcessMonitor
    @EnvironmentObject private var knowledgeBase: KnowledgeBase
    @EnvironmentObject private var themeManager: ThemeManager

    @Binding var selectedItem: NavItem

    private var hogCount: Int { processMonitor.resourceHogs.count }
    private var suggestionCount: Int { knowledgeBase.suggestions.count }
    private var criticalCount: Int {
        knowledgeBase.suggestions.filter { $0.severity == .critical }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Spacer to keep layout if needed, but no circles
            Color.clear.frame(height: 10)

            // Nav items
            navSection
                .padding(.horizontal, DS.Space.sm + 2)
                .padding(.top, DS.Space.sm)

            Spacer()

            Divider().opacity(0.4)

            // Footer vitals
            footerSection
        }
        .frame(minWidth: 180, idealWidth: DS.Size.sidebarWidth, maxWidth: 300)
        .background(colors.sidebar)
    }

    // MARK: - Nav

    private var navSection: some View {
        VStack(spacing: 0) {
            ForEach(NavItem.allCases) { item in
                navButton(item)
            }
        }
    }

    private func navButton(_ item: NavItem) -> some View {
        let selected = selectedItem == item

        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                selectedItem = item
            }
        } label: {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)

                Text(item.rawValue)
                    .font(AppFont.navUI)

                Spacer()

                if item == .processes && hogCount > 0 {
                    badge(hogCount, tone: .accent)
                } else if item == .suggestions && suggestionCount > 0 {
                    badge(suggestionCount, tone: criticalCount > 0 ? .danger : .warn)
                }
            }
            .padding(.horizontal, DS.Space.md - 2)
            .padding(.vertical, DS.Space.sm + 1)
            .frame(maxWidth: .infinity)
            .background(selected ? colors.ink : Color.clear)
            .foregroundStyle(selected ? colors.paper : colors.ink70)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.navItem, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.14), value: selected)
    }

    @ViewBuilder
    private func badge(_ count: Int, tone: ChipTone) -> some View {
        let bg: Color = {
            switch tone {
            case .danger: return colors.critical
            case .accent: return colors.accent
            case .warn:   return colors.warning
            default:      return colors.ink20
            }
        }()
        Text("\(count)")
            .font(AppFont.captionUI)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(Capsule())
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            miniVital(
                label: "MEM",
                value: processMonitor.usedRAM,
                max: processMonitor.totalRAM,
                unit: "GB",
                hue: colors.accent
            )
            miniVital(
                label: "SSD",
                value: processMonitor.diskUsedGB,
                max: processMonitor.diskTotalGB,
                unit: "GB",
                hue: colors.good
            )

            Divider().padding(.top, 2)

            // Theme toggle
            Button {
                themeManager.toggle()
            } label: {
                HStack(spacing: DS.Space.sm) {
                    Image(systemName: themeManager.currentTheme == .light ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 11))
                    Text(themeManager.currentTheme == .light ? "Dark mode" : "Light mode")
                        .font(AppFont.captionUI)
                }
                .foregroundStyle(colors.ink50)
            }
            .buttonStyle(.plain)

        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.md)
    }

    private func miniVital(label: String, value: Double, max: Double, unit: String, hue: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .eyebrowStyle()
                    .foregroundStyle(colors.ink50)
                Spacer()
                Text(String(format: "%.1f / %.0f %@", value, max, unit))
                    .font(AppFont.monoCaption)
                    .foregroundStyle(colors.ink50)
            }
            DSBar(value: value, maxValue: max, height: 3, hue: hue)
        }
    }
}
