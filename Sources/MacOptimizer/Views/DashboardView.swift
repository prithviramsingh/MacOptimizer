import SwiftUI

struct DashboardView: View {
    @Environment(\.themeColors) private var colors
    @EnvironmentObject private var processMonitor: ProcessMonitor
    @EnvironmentObject private var systemCleaner: SystemCleaner
    @EnvironmentObject private var knowledgeBase: KnowledgeBase

    @State private var cpuHistory: [Double] = Array(repeating: 0, count: 40)

    // MARK: - Derived state

    private var totalCPU: Double {
        processMonitor.processes.reduce(0) { $0 + $1.cpuPercent }
    }

    private var criticalCount: Int {
        knowledgeBase.suggestions.filter { $0.severity == .critical }.count
    }
    private var warningCount: Int {
        knowledgeBase.suggestions.filter { $0.severity == .warning }.count
    }

    private var healthHeadline: (String, String, Color) {
        if criticalCount > 0 {
            return ("Your Mac is ", "overworked right now", colors.critical)
        } else if warningCount > 1 {
            return ("Your Mac is ", "feeling the heat", colors.warning)
        } else {
            return ("Your Mac is ", "running clean", colors.good)
        }
    }

    private var healthChip: (String, ChipTone) {
        if criticalCount > 0  { return ("Needs Attention", .danger) }
        if warningCount > 0   { return ("Watch List", .warn) }
        return ("All Clear", .good)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {

                // Hero strip
                heroStrip

                // Vitals grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: DS.Space.md) {
                    DSCard(padding: DS.Space.lg) {
                        cpuCard
                    }
                    DSCard(padding: DS.Space.lg) {
                        DSVitalCard(
                            eyebrow: "Memory",
                            hero: String(format: "%.1f", processMonitor.usedRAM),
                            unit: "GB",
                            barValue: processMonitor.ramUsedPct,
                            barMax: 100,
                            footer: String(format: "of %.0f GB total", processMonitor.totalRAM)
                        )
                    }
                    DSCard(padding: DS.Space.lg) {
                        DSVitalCard(
                            eyebrow: "Storage",
                            hero: String(format: "%.0f", processMonitor.diskUsedGB),
                            unit: "GB used",
                            barValue: processMonitor.diskUsedPct,
                            barMax: 100,
                            barHue: colors.good,
                            footer: String(format: "of %.0f GB total", processMonitor.diskTotalGB)
                        )
                    }
                    DSCard(padding: DS.Space.lg) {
                        systemMiniCard
                    }
                }

                // Bottom row
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: DS.Space.md) {
                    topConsumersCard
                    attentionCard
                }
            }
            .padding(DS.Space.xl)
        }
        .background(colors.paper)
        .onChange(of: processMonitor.processes) { _ in
            var h = cpuHistory
            h.append(totalCPU)
            if h.count > 40 { h.removeFirst() }
            cpuHistory = h
        }
    }

    // MARK: - Hero Strip

    private var heroStrip: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.sm) {
                DSPulseDot()
                Text("Live")
                    .font(AppFont.captionUI)
                    .foregroundStyle(colors.ink50)
                Text("·")
                    .foregroundStyle(colors.ink30)
                
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(timeline.date, style: .time)
                        .font(AppFont.monoCaption)
                        .foregroundStyle(colors.ink50)
                }
                
                Spacer()
                DSChip(healthChip.0, tone: healthChip.1)
            }

            // Headline
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(healthHeadline.0)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(colors.ink)
                Text(healthHeadline.1)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(healthHeadline.2)
            }

            Text("\(processMonitor.processes.count) processes · \(processMonitor.resourceHogs.count) hogs · \(knowledgeBase.suggestions.count) suggestions")
                .font(AppFont.monoCaption)
                .foregroundStyle(colors.ink40)
        }
    }

    // MARK: - CPU Card

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DSEyebrow("CPU")

            HStack(alignment: .top, spacing: DS.Space.lg) {
                DSRing(value: totalCPU, size: 96, strokeWidth: 7)
                    .drawingGroup()

                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    DSSparkline(values: cpuHistory)
                        .frame(height: 44)
                        .drawingGroup()

                    if let topProc = processMonitor.processes.first {
                        HStack {
                            Text("peak")
                                .font(AppFont.monoCaption)
                                .foregroundStyle(colors.ink40)
                            Text(String(format: "%.1f%%", topProc.cpuPercent))
                                .font(AppFont.monoCaption)
                                .foregroundStyle(colors.ink70)
                        }
                    }
                    HStack {
                        Text("cores")
                            .font(AppFont.monoCaption)
                            .foregroundStyle(colors.ink40)
                        Text("\(ProcessInfo.processInfo.activeProcessorCount)")
                            .font(AppFont.monoCaption)
                            .foregroundStyle(colors.ink70)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - System Mini Card

    private var systemMiniCard: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DSEyebrow("System")

            VStack(alignment: .leading, spacing: DS.Space.sm) {
                miniStat(icon: "thermometer.medium", label: "Thermal", value: "Normal")
                miniStat(
                    icon: "battery.75percent",
                    label: "Uptime",
                    value: uptimeString
                )
                miniStat(
                    icon: "square.stack.3d.up",
                    label: "Processes",
                    value: "\(processMonitor.processes.count)"
                )
                if !processMonitor.hostname.isEmpty {
                    miniStat(icon: "desktopcomputer", label: "Host", value: processMonitor.hostname)
                }
            }
        }
    }

    private func miniStat(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(colors.ink40)
                .frame(width: 14)
            Text(label)
                .font(AppFont.captionUI)
                .foregroundStyle(colors.ink50)
            Spacer()
            Text(value)
                .font(AppFont.monoCaption)
                .foregroundStyle(colors.ink70)
        }
    }

    private var uptimeString: String {
        let secs = Int(-ProcessInfo.processInfo.systemUptime)
        let h = abs(secs) / 3600
        let m = (abs(secs) % 3600) / 60
        return "\(h)h \(m)m"
    }

    // MARK: - Top Consumers Card

    private var topConsumersCard: some View {
        DSCard(padding: 0) {
            VStack(spacing: 0) {
                DSEyebrow("Top Consumers") {
                    Text("\(processMonitor.processes.count) total")
                        .font(AppFont.captionUI)
                        .foregroundStyle(colors.ink40)
                }
                .padding(.horizontal, DS.Space.lg)
                .padding(.vertical, DS.Space.md)

                Divider().opacity(0.5)

                VStack(spacing: 0) {
                    ForEach(Array(processMonitor.processes.prefix(5).enumerated()), id: \.element.id) { index, proc in
                        consumerRow(rank: index + 1, process: proc)
                        if index < 4 {
                            Divider()
                                .padding(.leading, DS.Space.lg)
                                .opacity(0.4)
                        }
                    }
                }
            }
        }
    }

    private func consumerRow(rank: Int, process: ProcessSnapshot) -> some View {
        HStack(spacing: DS.Space.sm) {
            Text("\(rank)")
                .font(AppFont.monoCaption)
                .foregroundStyle(colors.ink30)
                .frame(width: 14, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(AppFont.ui(12.5, weight: .medium))
                    .foregroundStyle(colors.ink)
                    .lineLimit(1)
                Text(String(format: "PID %d · %.0f MB", process.pid, process.memoryMB))
                    .font(AppFont.monoCaption)
                    .foregroundStyle(colors.ink40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DSBar(value: process.cpuPercent, maxValue: 100, height: 3)
                .frame(width: 60)
                .drawingGroup()

            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(process.cpuPercent > 20 ? colors.accent : colors.ink70)
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm + 1)
    }

    // MARK: - Attention Card

    private var attentionCard: some View {
        DSCard(padding: 0) {
            VStack(spacing: 0) {
                DSEyebrow("Attention") {
                    if !knowledgeBase.suggestions.isEmpty {
                        Text("\(knowledgeBase.suggestions.count) items")
                            .font(AppFont.captionUI)
                            .foregroundStyle(colors.ink40)
                    }
                }
                .padding(.horizontal, DS.Space.lg)
                .padding(.vertical, DS.Space.md)

                Divider().opacity(0.5)

                if knowledgeBase.suggestions.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: DS.Space.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(colors.good)
                            Text("All clear")
                                .font(.system(size: 18, weight: .regular, design: .serif))
                                .foregroundStyle(colors.ink)
                        }
                        .padding(DS.Space.xl)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(knowledgeBase.suggestions.prefix(4).enumerated()), id: \.element.id) { index, sug in
                            attentionRow(sug)
                            if index < min(3, knowledgeBase.suggestions.count - 1) {
                                Divider()
                                    .padding(.leading, DS.Space.lg)
                                    .opacity(0.4)
                            }
                        }
                    }
                }
            }
        }
    }

    private func attentionRow(_ suggestion: Suggestion) -> some View {
        let severityColor: Color = {
            switch suggestion.severity {
            case .critical: return colors.critical
            case .warning:  return colors.warning
            case .info:     return colors.ink40
            }
        }()

        return HStack(spacing: DS.Space.sm) {
            Circle()
                .fill(severityColor)
                .frame(width: 6, height: 6)
            Text(suggestion.title)
                .font(AppFont.ui(12.5, weight: .medium))
                .foregroundStyle(colors.ink)
                .lineLimit(1)
            Spacer()
            DSChip(suggestion.severity.rawValue,
                   tone: suggestion.severity == .critical ? .danger :
                         suggestion.severity == .warning  ? .warn   : .neutral)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm + 1)
    }
}
