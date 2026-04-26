import SwiftUI
import Darwin

@MainActor
class ProcessMonitor: ObservableObject {
    @Published var processes: [ProcessSnapshot] = []
    @Published var resourceHogs: [ProcessSnapshot] = []
    @Published var processHistories: [String: ProcessHistory] = [:]
    @Published var isMonitoring = false

    // System vitals
    @Published var totalRAM:  Double = 0   // GB
    @Published var usedRAM:   Double = 0   // GB
    @Published var totalDisk: Int64  = 0   // bytes
    @Published var usedDisk:  Int64  = 0   // bytes
    @Published var hostname:  String = ""
    @Published var osVersion: String = ""

    var diskUsedGB:  Double { Double(usedDisk)  / 1_000_000_000 }
    var diskTotalGB: Double { Double(totalDisk) / 1_000_000_000 }
    var ramUsedPct:  Double { totalRAM > 0 ? (usedRAM / totalRAM) * 100 : 0 }
    var diskUsedPct: Double { diskTotalGB > 0 ? (diskUsedGB / diskTotalGB) * 100 : 0 }

    private var timer: Timer?
    private let shell = ShellRunner.shared
    private var knowledgeBase: KnowledgeBase?

    func startMonitoring(knowledgeBase: KnowledgeBase) {
        guard !isMonitoring else { return }
        self.knowledgeBase = knowledgeBase
        isMonitoring = true
        refreshSystemInfo()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }
        Task { await refresh() }
    }

    func refreshSystemInfo() {
        // RAM
        let physBytes = ProcessInfo.processInfo.physicalMemory
        totalRAM = Double(physBytes) / 1_073_741_824

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let pageSize = Double(vm_page_size)
            let active   = Double(vmStats.active_count)   * pageSize
            let wired    = Double(vmStats.wire_count)     * pageSize
            let compressed = Double(vmStats.compressor_page_count) * pageSize
            usedRAM = (active + wired + compressed) / 1_073_741_824
        }

        // Disk
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let total = attrs[.systemSize] as? Int64,
           let free  = attrs[.systemFreeSize] as? Int64 {
            totalDisk = total
            usedDisk  = total - free
        }

        // Host info
        hostname  = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    func refresh() async {
        guard let output = try? await shell.run("ps -axo pid=,pcpu=,rss=,user=,comm= 2>/dev/null") else { return }
        let snapshots = parsePS(output)

        var updatedHistories = processHistories
        for snap in snapshots {
            var history = updatedHistories[snap.name] ?? ProcessHistory(name: snap.name)
            history.addSample(cpu: snap.cpuPercent, memory: snap.memoryMB)
            updatedHistories[snap.name] = history
        }
        processHistories = updatedHistories
        processes    = snapshots.sorted { $0.cpuPercent > $1.cpuPercent }
        resourceHogs = snapshots.filter(\.isResourceHog).sorted { $0.cpuPercent > $1.cpuPercent }

        knowledgeBase?.analyze(processes: processes, histories: processHistories)
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
