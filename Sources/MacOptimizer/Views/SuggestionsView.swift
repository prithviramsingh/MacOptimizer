import SwiftUI

struct SuggestionsView: View {
    @EnvironmentObject var knowledgeBase:  KnowledgeBase
    @EnvironmentObject var processMonitor: ProcessMonitor

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Suggestions")
                    .font(.largeTitle).bold()
                Spacer()
                Button("Analyze Now") {
                    knowledgeBase.analyze(
                        processes: processMonitor.processes,
                        histories: processMonitor.processHistories
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Text("Mac Optimizer watches your processes over time and compares them against a built-in knowledge base to surface targeted performance fixes.")
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            if knowledgeBase.suggestions.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.green)
                    Text("No issues detected")
                        .font(.title2).bold()
                    Text("Your Mac appears healthy. Click Analyze Now to rescan running processes.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(knowledgeBase.suggestions) { suggestion in
                            SuggestionCard(suggestion: suggestion)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: Suggestion
    @State private var isExpanded = false

    var severityColor: Color {
        switch suggestion.severity {
        case .critical: return .red
        case .warning:  return .orange
        case .info:     return .blue
        }
    }

    var severityIcon: String {
        switch suggestion.severity {
        case .critical: return "exclamationmark.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .info:     return "info.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .fontWeight(.semibold)

                    if isExpanded {
                        Text(suggestion.detail)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)

                        HStack(spacing: 6) {
                            Text(suggestion.category.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())

                            if let actionLabel = suggestion.actionLabel {
                                Text(actionLabel)
                                    .font(.caption)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(severityColor.opacity(0.15))
                                    .foregroundColor(severityColor)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(suggestion.severity.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(severityColor.opacity(0.15))
                        .foregroundColor(severityColor)
                        .clipShape(Capsule())

                    Button(isExpanded ? "Less" : "Details") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(severityColor.opacity(0.25), lineWidth: 1)
        )
    }
}
