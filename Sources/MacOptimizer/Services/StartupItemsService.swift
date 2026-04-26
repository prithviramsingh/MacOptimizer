import Foundation
import SwiftUI

struct StartupItem: Identifiable {
    let id = UUID()
    let label: String
    let path: String
    let programPath: String
    var isEnabled: Bool
    let source: Source

    enum Source: String, CaseIterable {
        case launchAgent  = "Launch Agent"
        case launchDaemon = "Launch Daemon"
    }
}

@MainActor
class StartupItemsService: ObservableObject {
    @Published var items: [StartupItem] = []
    @Published var isLoading = false

    private let shell = ShellRunner.shared
    private let fm    = FileManager.default

    func load() async {
        isLoading = true
        var result: [StartupItem] = []

        let home = fm.homeDirectoryForCurrentUser.path
        let searchPaths: [(String, StartupItem.Source)] = [
            ("\(home)/Library/LaunchAgents",  .launchAgent),
            ("/Library/LaunchAgents",          .launchAgent),
            ("/Library/LaunchDaemons",         .launchDaemon)
        ]

        for (dirPath, source) in searchPaths {
            guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files where file.hasSuffix(".plist") {
                let fullPath = "\(dirPath)/\(file)"
                if let item = parsePlist(at: fullPath, source: source) {
                    result.append(item)
                }
            }
        }

        // Determine which labels are currently loaded via launchctl
        let loadedOutput = (try? await shell.run("launchctl list 2>/dev/null")) ?? ""
        let loadedLabels = Set(
            loadedOutput.split(separator: "\n").compactMap { line -> String? in
                let parts = line.split(separator: "\t")
                return parts.count >= 3 ? String(parts[2]) : nil
            }
        )

        items = result.map { item in
            var copy = item
            copy.isEnabled = loadedLabels.contains(item.label)
            return copy
        }
        .sorted { $0.label < $1.label }

        isLoading = false
    }

    func toggle(_ item: StartupItem) async {
        let cmd = item.isEnabled
            ? "launchctl unload -w '\(item.path)'"
            : "launchctl load -w '\(item.path)'"
        
        do {
            if item.source == .launchDaemon {
                _ = try await shell.runWithAdmin(cmd)
            } else {
                _ = try await shell.run(cmd)
            }
        } catch {
            print("Failed to toggle startup item: \(error)")
        }
        await load()
    }

    // MARK: - Private

    private func parsePlist(at path: String, source: StartupItem.Source) -> StartupItem? {
        guard let dict  = NSDictionary(contentsOfFile: path),
              let label = dict["Label"] as? String else { return nil }

        var program = "Unknown"
        if let prog = dict["Program"] as? String {
            program = prog
        } else if let args = dict["ProgramArguments"] as? [String], let first = args.first {
            program = first
        }

        return StartupItem(
            label:       label,
            path:        path,
            programPath: program,
            isEnabled:   false,   // resolved later via launchctl
            source:      source
        )
    }
}
