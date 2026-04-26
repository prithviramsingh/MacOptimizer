import SwiftUI

struct SuggestionsView: View {
    @Environment(\.themeColors) private var colors
    @EnvironmentObject private var knowledgeBase:  KnowledgeBase
    @EnvironmentObject private var processMonitor: ProcessMonitor

    @State private var severityFilter: SeverityFilter = .all

    enum SeverityFilter: String, CaseIterable {
        case all = "All", critical = "Critical", warning = "Warning", info = "Info"
    }

    // MARK: - Derived

    private var criticalCount: Int { knowledgeBase.suggestions.filter { $0.severity == .critical }.count }
    private var warningCount:  Int { knowledgeBase.suggestions.filter { $0.severity == .warning  }.count }
    private var infoCount:     Int { knowledgeBase.suggestions.filter { $0.severity == .info     }.count }

    private var displayed: [Suggestion] {
        switch severityFilter {
        case .all:      return knowledgeBase.suggestions
        case .critical: return knowledgeBase.suggestions.filter { $0.severity == .critical }
        case .warning:  return knowledgeBase.suggestions.filter { $0.severity == .warning  }
        case .info:     return knowledgeBase.suggestions.filter { $0.severity == .info     }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                headerSection

                if displayed.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320))], spacing: DS.Space.md) {
                        ForEach(displayed) { sug in
                            SuggestionCard(suggestion: sug)
                        }
                    }
                }
            }
            .padding(DS.Space.xl)
        }
        .background(colors.paper)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DSEyebrow("Suggestions")

            HStack(alignment: .firstTextBaseline) {
                if knowledgeBase.suggestions.isEmpty {
                    Text("All clear. ")
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .foregroundStyle(colors.ink)
                    Text("Nothing to fix.")
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(colors.goodStrong)
                } else {
                    Text("\(knowledgeBase.suggestions.count) ")
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .foregroundStyle(colors.accent)
                        .italic()
                    Text("fixes ranked by impact")
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .foregroundStyle(colors.ink)
                }
                Spacer()
                DSBtn("Analyze", variant: .ghost, small: true) {
                    knowledgeBase.analyze(processes: processMonitor.processes, histories: processMonitor.processHistories)
                }
            }

            // Filter buttons
            HStack(spacing: DS.Space.xs) {
                filterBtn(.all,      count: knowledgeBase.suggestions.count)
                filterBtn(.critical, count: criticalCount)
                filterBtn(.warning,  count: warningCount)
                filterBtn(.info,     count: infoCount)
            }
        }
    }

    private func filterBtn(_ f: SeverityFilter, count: Int) -> some View {
        let active = severityFilter == f
        let tone: ChipTone = f == .critical ? .danger : f == .warning ? .warn : f == .info ? .neutral : .neutral

        return Button {
            withAnimation(.easeInOut(duration: 0.14)) { severityFilter = f }
        } label: {
            HStack(spacing: 4) {
                Text(f.rawValue)
                    .font(AppFont.ui(12, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(AppFont.monoCaption)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(active ? Color.white.opacity(0.2) : severityBg(tone))
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(active ? (f == .critical ? Color.white : f == .warning ? Color.white : colors.ink) : colors.ink70)
            .padding(.horizontal, DS.Space.sm + 2)
            .padding(.vertical, 6)
            .background(active ? activeBg(f) : colors.ink8)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func activeBg(_ f: SeverityFilter) -> Color {
        switch f {
        case .critical: return colors.critical
        case .warning:  return colors.warning
        default:        return colors.ink
        }
    }

    private func severityBg(_ tone: ChipTone) -> Color {
        switch tone {
        case .danger: return colors.critical.opacity(0.15)
        case .warn:   return colors.warning.opacity(0.15)
        default:      return colors.ink10
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        DSCard(padding: DS.Space.xxl) {
            VStack(spacing: DS.Space.sm) {
                ZStack {
                    Circle()
                        .fill(colors.good10)
                        .frame(width: 56, height: 56)
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(colors.goodStrong)
                }
                Text("Nothing to flag.")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(colors.ink)
                Text("Your system is running efficiently.")
                    .font(AppFont.bodyUI)
                    .foregroundStyle(colors.ink50)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    @Environment(\.themeColors) private var colors
    @EnvironmentObject private var knowledgeBase: KnowledgeBase
    @EnvironmentObject private var processMonitor: ProcessMonitor

    let suggestion: Suggestion
    @State private var isExpanded = false

    private var severityColor: Color {
        switch suggestion.severity {
        case .critical: return colors.critical
        case .warning:  return colors.warning
        case .info:     return colors.ink40
        }
    }

    private var severityTone: ChipTone {
        switch suggestion.severity {
        case .critical: return .danger
        case .warning:  return .warn
        case .info:     return .neutral
        }
    }

    private var categoryTone: ChipTone { .neutral }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Colored top border
            severityColor
                .frame(height: 4)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                .clipShape(
                    .rect(topLeadingRadius: DS.Radius.card, bottomLeadingRadius: 0,
                          bottomTrailingRadius: 0, topTrailingRadius: DS.Radius.card)
                )

            VStack(alignment: .leading, spacing: DS.Space.sm) {
                // Chips row
                HStack(spacing: DS.Space.xs) {
                    DSChip(suggestion.severity.rawValue, tone: severityTone)
                    DSChip(suggestion.category.rawValue, tone: categoryTone)
                    Spacer()
                }

                // Title
                Text(suggestion.title)
                    .font(AppFont.ui(15, weight: .semibold))
                    .foregroundStyle(colors.ink)
                    .fixedSize(horizontal: false, vertical: true)

                // Detail (expandable)
                if isExpanded || suggestion.detail.count < 120 {
                    Text(suggestion.detail)
                        .font(AppFont.bodyUI)
                        .foregroundStyle(colors.ink60)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(String(suggestion.detail.prefix(120)) + "…")
                        .font(AppFont.bodyUI)
                        .foregroundStyle(colors.ink60)
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { isExpanded = true } }
                }

                // Actions
                HStack(spacing: DS.Space.xs) {
                    if let label = suggestion.actionLabel {
                        DSBtn(label, variant: .solid, small: true) {
                            knowledgeBase.analyze(
                                processes: processMonitor.processes,
                                histories: processMonitor.processHistories
                            )
                        }
                    }
                    DSBtn("Dismiss", variant: .ghost, small: true) {
                        // No-op: suggestions are re-derived; user can re-analyze
                    }
                    Spacer()
                }
            }
            .padding(DS.Space.lg)
        }
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .strokeBorder(colors.ink8, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}
