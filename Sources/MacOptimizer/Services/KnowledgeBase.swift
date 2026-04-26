import SwiftUI

// MARK: - Environment key for the static process DB
// Using @Environment (not @EnvironmentObject) means views that only need the DB
// don't subscribe to KnowledgeBase's @Published changes.

private struct ProcessKnowledgeDBKey: EnvironmentKey {
    static let defaultValue: [String: ProcessKnowledge] = [:]
}

extension EnvironmentValues {
    var processKnowledgeDB: [String: ProcessKnowledge] {
        get { self[ProcessKnowledgeDBKey.self] }
        set { self[ProcessKnowledgeDBKey.self] = newValue }
    }
}

struct ProcessKnowledge {
    let displayName: String
    let description: String
    let highCPUSuggestion: String?
    let highMemSuggestion: String?
    let safeToKill: Bool
}

@MainActor
class KnowledgeBase: ObservableObject {
    @Published var suggestions: [Suggestion] = []

    // MARK: - Known-process database

    let db: [String: ProcessKnowledge] = [
        "mds_stores": ProcessKnowledge(
            displayName: "Spotlight Indexer",
            description: "Indexes your files for Spotlight search.",
            highCPUSuggestion: "Add large or external drives to Spotlight's privacy exclusion list: System Settings → Siri & Spotlight → Spotlight Privacy. CPU usage drops once initial indexing finishes.",
            highMemSuggestion: "Spotlight is re-indexing. This is temporary — memory usage will fall when indexing completes.",
            safeToKill: false
        ),
        "kernel_task": ProcessKnowledge(
            displayName: "macOS Kernel",
            description: "High kernel_task CPU means macOS is intentionally throttling the CPU to protect against heat.",
            highCPUSuggestion: "Your Mac is thermal throttling. Place it on a hard, flat surface, clear any vents, and avoid stacking CPU-heavy tasks until the chassis cools down.",
            highMemSuggestion: nil,
            safeToKill: false
        ),
        "WindowServer": ProcessKnowledge(
            displayName: "Window Server",
            description: "Composites all windows and renders the macOS UI.",
            highCPUSuggestion: "Reduce visual effects: System Settings → Accessibility → Display → enable Reduce Motion and Reduce Transparency.",
            highMemSuggestion: nil,
            safeToKill: false
        ),
        "coreaudiod": ProcessKnowledge(
            displayName: "Core Audio Daemon",
            description: "Manages audio I/O on macOS.",
            highCPUSuggestion: "Restart Core Audio (no reboot needed): sudo killall coreaudiod. This resets all audio devices.",
            highMemSuggestion: nil,
            safeToKill: true
        ),
        "Google Chrome Helper": ProcessKnowledge(
            displayName: "Chrome Renderer",
            description: "Each Chrome tab and extension runs as a separate Helper process.",
            highCPUSuggestion: "Open Chrome's built-in Task Manager (⇧Esc) to find and close the offending tab or extension.",
            highMemSuggestion: "Chrome uses memory aggressively. Close unused tabs, disable unused extensions, or switch resource-light browsing to Safari.",
            safeToKill: true
        ),
        "Google Chrome Helper (Renderer)": ProcessKnowledge(
            displayName: "Chrome Renderer",
            description: "Renders a Chrome tab or extension.",
            highCPUSuggestion: "Open Chrome's Task Manager (⇧Esc) to identify and close the specific tab or extension consuming CPU.",
            highMemSuggestion: "Close unused Chrome tabs or restart Chrome to compact memory.",
            safeToKill: true
        ),
        "com.apple.WebKit.WebContent": ProcessKnowledge(
            displayName: "Safari Web Content",
            description: "Renders a Safari tab.",
            highCPUSuggestion: "Open Safari → Window → Task Force to find and close the heavy tab.",
            highMemSuggestion: "Reload the tab (⌘R) or close unused Safari tabs to reclaim memory.",
            safeToKill: true
        ),
        "cloudd": ProcessKnowledge(
            displayName: "iCloud Daemon",
            description: "Syncs files with iCloud Drive.",
            highCPUSuggestion: "iCloud is actively syncing. Wait for it to finish. If it persists for hours, sign out of iCloud and back in via System Settings → Apple ID.",
            highMemSuggestion: nil,
            safeToKill: false
        ),
        "backupd": ProcessKnowledge(
            displayName: "Time Machine",
            description: "Performs Time Machine backups.",
            highCPUSuggestion: "A backup is running. You can pause it: tmutil stopbackup. Consider scheduling backups during off-hours.",
            highMemSuggestion: nil,
            safeToKill: false
        ),
        "softwareupdated": ProcessKnowledge(
            displayName: "Software Update",
            description: "Downloads macOS software updates in the background.",
            highCPUSuggestion: "macOS is downloading an update. Let it finish, or pause in System Settings → General → Software Update.",
            highMemSuggestion: nil,
            safeToKill: false
        ),
        "mediaanalysisd": ProcessKnowledge(
            displayName: "Media Analysis",
            description: "Analyses photos/videos for face recognition and scene detection.",
            highCPUSuggestion: "Photos is analysing your library. This is a one-time process after import. Quit Photos to pause it.",
            highMemSuggestion: nil,
            safeToKill: false
        ),
        "Xcode": ProcessKnowledge(
            displayName: "Xcode",
            description: "Apple's IDE.",
            highCPUSuggestion: "Xcode is building or indexing. You can disable background indexing under Xcode → Settings → General. Close unused projects.",
            highMemSuggestion: "Restart Xcode to reclaim memory. Close simulator windows and unused project tabs.",
            safeToKill: true
        ),
        "Slack": ProcessKnowledge(
            displayName: "Slack",
            description: "Electron-based team messaging app.",
            highCPUSuggestion: "Quit and relaunch Slack, or use the web version (slack.com) for lighter resource usage.",
            highMemSuggestion: "Slack (Electron) can use 500 MB+. Consider the web version or disabling auto-launch at login.",
            safeToKill: true
        ),
        "node": ProcessKnowledge(
            displayName: "Node.js",
            description: "JavaScript runtime — likely a development server or build tool.",
            highCPUSuggestion: "A Node.js process is spinning. Check your terminal for a runaway watch/build script and restart it.",
            highMemSuggestion: "Node.js processes can grow over time. Restart dev servers periodically.",
            safeToKill: true
        ),
        "mds": ProcessKnowledge(
            displayName: "Spotlight Metadata Server",
            description: "Coordinates Spotlight indexing.",
            highCPUSuggestion: "Related to Spotlight. See mds_stores recommendation above.",
            highMemSuggestion: nil,
            safeToKill: false
        ),
        "com.apple.MobileSMS": ProcessKnowledge(
            displayName: "Messages",
            description: "The macOS Messages app.",
            highCPUSuggestion: "Restart Messages. If persistent, check for a large message history that may be syncing.",
            highMemSuggestion: nil,
            safeToKill: true
        ),
    ]

    // MARK: - Analysis

    func analyze(processes: [ProcessSnapshot], histories: [String: ProcessHistory]) {
        var results: [Suggestion] = []

        for process in processes where process.cpuPercent > 15 || process.memoryMB > 400 {
            if let knowledge = db[process.name] {
                if process.cpuPercent > 15, let tip = knowledge.highCPUSuggestion {
                    results.append(Suggestion(
                        title:       "\(knowledge.displayName) using \(String(format: "%.1f", process.cpuPercent))% CPU",
                        detail:      tip,
                        severity:    process.cpuPercent > 60 ? .critical : .warning,
                        category:    .process,
                        actionLabel: knowledge.safeToKill ? "Kill Process" : nil
                    ))
                }
                if process.memoryMB > 400, let tip = knowledge.highMemSuggestion {
                    results.append(Suggestion(
                        title:       "\(knowledge.displayName) using \(Int(process.memoryMB)) MB RAM",
                        detail:      tip,
                        severity:    process.memoryMB > 1200 ? .critical : .warning,
                        category:    .memory,
                        actionLabel: nil
                    ))
                }
            } else if process.cpuPercent > 50 {
                results.append(Suggestion(
                    title:       "\(process.name) using \(String(format: "%.1f", process.cpuPercent))% CPU",
                    detail:      "This unrecognised process is consuming significant CPU. Investigate it in Activity Monitor (⌘Space → Activity Monitor).",
                    severity:    .warning,
                    category:    .process,
                    actionLabel: nil
                ))
            }
        }

        // Persistent CPU hogs in history (sustained over multiple samples)
        for (name, history) in histories where history.samples.count >= 6 && history.avgCPU > 12 {
            let alreadyCovered = results.contains { $0.title.contains(name) }
            if !alreadyCovered {
                let minutes = history.samples.count * 5 / 60
                results.append(Suggestion(
                    title:       "\(name) averaging \(String(format: "%.1f", history.avgCPU))% CPU",
                    detail:      "This process has sustained high CPU for ~\(max(1, minutes)) minute(s). Consider restarting its parent application.",
                    severity:    .info,
                    category:    .process,
                    actionLabel: nil
                ))
            }
        }

        // Deduplicate and cap
        suggestions = Array(
            results
                .sorted { $0.severity.rank > $1.severity.rank }
                .prefix(25)
        )
    }
}

private extension Suggestion.Severity {
    var rank: Int {
        switch self {
        case .critical: return 2
        case .warning:  return 1
        case .info:     return 0
        }
    }
}
