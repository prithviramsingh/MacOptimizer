import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var processMonitor: ProcessMonitor
    @EnvironmentObject var systemCleaner: SystemCleaner
    @EnvironmentObject var knowledgeBase: KnowledgeBase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                Text("System Overview")
                    .font(.largeTitle).bold()

                // Stat cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "Active Processes",
                        value: "\(processMonitor.processes.count)",
                        icon:  "cpu",
                        color: .blue
                    )
                    StatCard(
                        title: "Resource Hogs",
                        value: "\(processMonitor.resourceHogs.count)",
                        icon:  "exclamationmark.triangle",
                        color: processMonitor.resourceHogs.isEmpty ? .green : .orange
                    )
                    StatCard(
                        title: "Suggestions",
                        value: "\(knowledgeBase.suggestions.count)",
                        icon:  "lightbulb",
                        color: knowledgeBase.suggestions.isEmpty ? .green : .yellow
                    )
                }

                // Top resource consumers
                if !processMonitor.resourceHogs.isEmpty {
                    SectionBox(title: "Top Resource Consumers", icon: "flame") {
                        ForEach(processMonitor.resourceHogs.prefix(5)) { process in
                            HStack {
                                Text(process.name)
                                    .lineLimit(1)
                                    .frame(minWidth: 140, alignment: .leading)
                                Spacer()
                                Text(String(format: "CPU %.1f%%", process.cpuPercent))
                                    .foregroundColor(process.cpuPercent > 50 ? .red : .orange)
                                    .frame(width: 90, alignment: .trailing)
                                Text(String(format: "%.0f MB", process.memoryMB))
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, alignment: .trailing)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }

                // Top suggestions preview
                if !knowledgeBase.suggestions.isEmpty {
                    SectionBox(title: "Latest Suggestions", icon: "lightbulb") {
                        ForEach(knowledgeBase.suggestions.prefix(3)) { suggestion in
                            SuggestionRow(suggestion: suggestion)
                            Divider()
                        }
                    }
                }

                if processMonitor.resourceHogs.isEmpty && knowledgeBase.suggestions.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 52))
                                .foregroundColor(.green)
                            Text("Your Mac looks healthy!")
                                .font(.title2).bold()
                            Text("No resource hogs or performance issues detected.")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 40)
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Supporting views

struct StatCard: View {
    let title: String
    let value: String
    let icon:  String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct SectionBox<Content: View>: View {
    let title:   String
    let icon:    String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct SuggestionRow: View {
    let suggestion: Suggestion

    var severityColor: Color {
        switch suggestion.severity {
        case .critical: return .red
        case .warning:  return .orange
        case .info:     return .blue
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(severityColor)
                .frame(width: 8, height: 8)
            Text(suggestion.title)
                .lineLimit(1)
            Spacer()
            Text(suggestion.severity.rawValue)
                .font(.caption)
                .foregroundColor(severityColor)
        }
        .padding(.vertical, 4)
    }
}
