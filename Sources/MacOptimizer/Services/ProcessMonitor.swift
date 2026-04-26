import SwiftUI
import Darwin

// Constants from <sys/proc_info.h>
private let PROC_ALL_PIDS_TYPE: UInt32 = 1
private let PROC_PIDTASKINFO_FLAVOR: Int32 = 4

@MainActor
class ProcessMonitor: ObservableObject {
    @Published var processes: [ProcessSnapshot] = []
    @Published var resourceHogs: [ProcessSnapshot] = []
    @Published var processHistories: [String: ProcessHistory] = [:]
    @Published var isMonitoring = false

    // System vitals
    @Published var systemCPUPercent: Double = 0
    @Published var totalRAM:    Double = 0   // GB
    @Published var usedRAM:     Double = 0   // GB
    @Published var swapUsedGB:  Double = 0
    @Published var swapTotalGB: Double = 0
    @Published var totalDisk:   Int64  = 0   // bytes
    @Published var usedDisk:    Int64  = 0   // bytes
    @Published var hostname:    String = ""
    @Published var osVersion:   String = ""

    var diskUsedGB:  Double { Double(usedDisk)  / 1_000_000_000 }
    var diskTotalGB: Double { Double(totalDisk) / 1_000_000_000 }
    var ramUsedPct:  Double { totalRAM > 0 ? (usedRAM / totalRAM) * 100 : 0 }
    var diskUsedPct: Double { diskTotalGB > 0 ? (diskUsedGB / diskTotalGB) * 100 : 0 }

    private var timer: Timer?
    private var knowledgeBase: KnowledgeBase?
    private let shell = ShellRunner.shared

    // Delta tracking for system-wide CPU ticks
    private var prevTicks: (user: UInt64, sys: UInt64, idle: UInt64) = (0, 0, 0)

    func startMonitoring(knowledgeBase: KnowledgeBase) {
        guard !isMonitoring else { return }
        self.knowledgeBase = knowledgeBase
        isMonitoring = true
        refreshStaticInfo()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.refresh() }
        }
        Task { await refresh() }
    }

    func refreshStaticInfo() {
        totalRAM = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let total = attrs[.systemSize] as? Int64,
           let free  = attrs[.systemFreeSize] as? Int64 {
            totalDisk = total
            usedDisk  = total - free
        }
        hostname  = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    func refresh() async {
        // To match Activity Monitor perfectly, we use 'top' which gets the kernel-calculated instantaneous CPU%
        // and footprint/resident memory across a short delta.
        guard let output = try? await shell.run("top -l 2 -s 0 -n 250 -stats pid,cpu,mem,user,command 2>/dev/null") else { return }
        
        let snapshots = parseTop(output)

        refreshRAM()
        refreshSwap()
        refreshSystemCPU()

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
        Darwin.kill(pid, SIGKILL)
        await refresh()
    }

    // MARK: - Parsing

    private func parseTop(_ output: String) -> [ProcessSnapshot] {
        let lines = output.components(separatedBy: .newlines)
        var results: [ProcessSnapshot] = []
        results.reserveCapacity(lines.count)

        var isSecondPass = false
        var passCount = 0

        for line in lines {
            if line.hasPrefix("PID") {
                passCount += 1
                if passCount == 2 {
                    isSecondPass = true
                }
                continue
            }

            guard isSecondPass else { continue }
            
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard parts.count >= 5 else { continue }

            let pid = Int32(parts[0]) ?? 0
            
            // Handle locale-specific decimals
            let cpuStr = String(parts[1]).replacingOccurrences(of: ",", with: ".")
            let cpu = Double(cpuStr) ?? 0

            var memStr = String(parts[2])
            if memStr.hasSuffix("+") || memStr.hasSuffix("-") {
                memStr.removeLast()
            }
            
            var memoryMB: Double = 0
            if memStr.hasSuffix("M") {
                memStr.removeLast()
                memoryMB = Double(memStr.replacingOccurrences(of: ",", with: ".")) ?? 0
            } else if memStr.hasSuffix("K") {
                memStr.removeLast()
                memoryMB = (Double(memStr.replacingOccurrences(of: ",", with: ".")) ?? 0) / 1024.0
            } else if memStr.hasSuffix("G") {
                memStr.removeLast()
                memoryMB = (Double(memStr.replacingOccurrences(of: ",", with: ".")) ?? 0) * 1024.0
            } else if memStr.hasSuffix("B") {
                memStr.removeLast()
                memoryMB = (Double(memStr.replacingOccurrences(of: ",", with: ".")) ?? 0) / (1024.0 * 1024.0)
            } else {
                memoryMB = (Double(memStr.replacingOccurrences(of: ",", with: ".")) ?? 0) / (1024.0 * 1024.0)
            }

            let user = String(parts[3]).trimmingCharacters(in: .whitespaces)
            let comm = String(parts[4]).trimmingCharacters(in: .whitespaces)

            // Clean up path from command
            let name = URL(fileURLWithPath: comm).lastPathComponent.trimmingCharacters(in: .whitespaces)

            results.append(ProcessSnapshot(
                pid: pid,
                name: name,
                cpuPercent: cpu,
                memoryMB: memoryMB,
                user: user
            ))
        }
        return results
    }

    // MARK: - System CPU via host_processor_info tick deltas

    private func refreshSystemCPU() {
        var infoArray: processor_info_array_t?
        var msgCount: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &numCPUs, &infoArray, &msgCount) == KERN_SUCCESS,
              let info = infoArray else { return }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(msgCount) * vm_size_t(MemoryLayout<integer_t>.size))
        }

        var user: UInt64 = 0, sys: UInt64 = 0, idle: UInt64 = 0
        for i in 0..<Int(numCPUs) {
            let base = i * Int(CPU_STATE_MAX)
            user += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            sys  += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            idle += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
        }

        let prev = prevTicks
        prevTicks = (user, sys, idle)
        guard prev.user + prev.sys + prev.idle > 0 else { return }

        let dUser = user &- prev.user
        let dSys  = sys  &- prev.sys
        let dIdle = idle &- prev.idle
        let total = dUser + dSys + dIdle
        if total > 0 {
            systemCPUPercent = Double(dUser + dSys) / Double(total) * 100
        }
    }

    private func refreshRAM() {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let page = Double(vm_page_size)
            // Activity Monitor "Memory Used" ≈ (Active + Inactive + Wired + Compressed) - Purgeable
            let activePages   = Double(vmStats.active_count)
            let inactivePages = Double(vmStats.inactive_count)
            let wiredPages    = Double(vmStats.wire_count)
            let compressed    = Double(vmStats.compressor_page_count)
            let purgeable     = Double(vmStats.purgeable_count)
            
            usedRAM = (activePages + inactivePages + wiredPages + compressed - purgeable) * page / 1_073_741_824
        }
    }

    private func refreshSwap() {
        var swapInfo = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapInfo, &size, nil, 0) == 0 {
            swapUsedGB  = Double(swapInfo.xsu_used)  / 1_073_741_824
            swapTotalGB = Double(swapInfo.xsu_total) / 1_073_741_824
        }
    }
}
