import SwiftUI

@MainActor
class ProcessMonitor: ObservableObject {
    @Published var processes: [ProcessSnapshot] = []
    @Published var resourceHogs: [ProcessSnapshot] = []
    @Published var processHistories: [String: ProcessHistory] = [:]
    @Published var isMonitoring = false

    private var timer: Timer?
    private let shell = ShellRunner.shared

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }
        Task { await refresh() }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    func refresh() async {
        guard let output = try? await shell.run("ps -axo pid=,pcpu=,rss=,user=,comm= 2>/dev/null") else { return }
        let snapshots = parsePS(output)

        for snap in snapshots {
            var history = processHistories[snap.name] ?? ProcessHistory(name: snap.name)
            history.addSample(cpu: snap.cpuPercent, memory: snap.memoryMB)
            processHistories[snap.name] = history
        }

        processes    = snapshots.sorted { $0.cpuPercent > $1.cpuPercent }
        resourceHogs = snapshots.filter(\.isResourceHog).sorted { $0.cpuPercent > $1.cpuPercent }
    }

    func killProcess(_ pid: Int32) async {
        _ = try? await shell.run("kill -9 \(pid)")
        await refresh()
    }

    // MARK: - Parsing

    private func parsePS(_ output: String) -> [ProcessSnapshot] {
        output.split(separator: "\n").compactMap { line -> ProcessSnapshot? in
            let parts = line
                .trimmingCharacters(in: .whitespaces)
                .split(separator: " ", maxSplits: 4)
                .map(String.init)
            guard parts.count == 5,
                  let pid    = Int32(parts[0]),
                  let cpu    = Double(parts[1]),
                  let rssKB  = Int64(parts[2]) else { return nil }

            let user    = parts[3]
            let command = parts[4]
            let name    = URL(fileURLWithPath: command).lastPathComponent

            return ProcessSnapshot(
                pid:          pid,
                name:         name,
                cpuPercent:   cpu,
                memoryMB:     Double(rssKB) / 1024.0,
                user:         user
            )
        }
    }
}
