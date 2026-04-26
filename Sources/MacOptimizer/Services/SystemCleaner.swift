import SwiftUI

@MainActor
class SystemCleaner: ObservableObject {
    @Published var items: [CleanupItem] = []
    @Published var isScanning   = false
    @Published var isCleaning   = false
    @Published var dryRun       = true
    @Published var cleanedBytes: Int64 = 0
    @Published var log: [String] = []

    private let shell = ShellRunner.shared
    private let fm    = FileManager.default

    var selectedItems: [CleanupItem] { items.filter(\.isSelected) }
    var selectedSize:  Int64          { selectedItems.map(\.sizeBytes).reduce(0, +) }

    // MARK: - Scan

    func scan() async {
        isScanning = true
        items = []

        async let userCaches = scanUserCaches()
        async let logs       = scanLogs()
        async let xcode      = scanXcode()
        async let iosBackups = scanIOSBackups()

        var results = await userCaches + logs + xcode + iosBackups
        results.append(dnsCacheItem())

        items = results.sorted { $0.sizeBytes > $1.sizeBytes }
        isScanning = false
    }

    // MARK: - Clean

    func clean() async {
        isCleaning   = true
        cleanedBytes = 0
        log          = []

        for item in selectedItems {
            if dryRun {
                log.append("[DRY RUN] Would remove: \(item.name) (\(item.formattedSize))")
            } else {
                do {
                    try await performClean(item)
                    cleanedBytes += item.sizeBytes
                    log.append("✓ Cleaned: \(item.name) (\(item.formattedSize))")
                } catch {
                    log.append("✗ Failed:  \(item.name) — \(error.localizedDescription)")
                }
            }
        }

        if dryRun {
            let total = ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
            log.append("")
            log.append("Total that would be freed: \(total)")
        } else {
            let freed = ByteCountFormatter.string(fromByteCount: cleanedBytes, countStyle: .file)
            log.append("")
            log.append("Total freed: \(freed)")
        }

        isCleaning = false
    }

    // MARK: - Private helpers

    private func performClean(_ item: CleanupItem) async throws {
        switch item.category {
        case .dns:
            _ = try await shell.runWithAdmin(
                "dscacheutil -flushcache && killall -HUP mDNSResponder"
            )
        default:
            _ = try await shell.run("rm -rf '\(item.path)'")
        }
    }

    private func scanUserCaches() async -> [CleanupItem] {
        let cachesDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches").path
        guard let entries = try? fm.contentsOfDirectory(atPath: cachesDir) else { return [] }

        // Increase scan depth to 100 and parallelise size checks
        return await withTaskGroup(of: CleanupItem?.self) { group in
            for entry in entries.prefix(100) {
                let fullPath = "\(cachesDir)/\(entry)"
                group.addTask {
                    let size = await self.shell.directorySize(at: fullPath)
                    guard size > 1_024 * 1_024 else { return nil } // skip < 1MB
                    return CleanupItem(
                        name:        entry,
                        path:        fullPath,
                        sizeBytes:   size,
                        category:    .userCache,
                        description: "Application cache in ~/Library/Caches"
                    )
                }
            }
            
            var result: [CleanupItem] = []
            for await item in group {
                if let item = item {
                    result.append(item)
                }
            }
            return result
        }
    }

    private func scanLogs() async -> [CleanupItem] {
        let logsDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs").path
        let size = await shell.directorySize(at: logsDir)
        guard size > 0 else { return [] }
        return [CleanupItem(
            name:        "User Logs",
            path:        logsDir,
            sizeBytes:   size,
            category:    .logs,
            description: "Application logs in ~/Library/Logs"
        )]
    }

    private func scanXcode() async -> [CleanupItem] {
        let home = fm.homeDirectoryForCurrentUser.path
        var result: [CleanupItem] = []

        let derivedData = "\(home)/Library/Developer/Xcode/DerivedData"
        let derivedSize = await shell.directorySize(at: derivedData)
        if derivedSize > 0 {
            result.append(CleanupItem(
                name:        "Xcode DerivedData",
                path:        derivedData,
                sizeBytes:   derivedSize,
                category:    .xcode,
                description: "Compiled Xcode build artifacts — safe to delete"
            ))
        }

        let simulators = "\(home)/Library/Developer/CoreSimulator/Devices"
        let simSize    = await shell.directorySize(at: simulators)
        if simSize > 0 {
            result.append(CleanupItem(
                name:        "iOS Simulator Data",
                path:        simulators,
                sizeBytes:   simSize,
                category:    .xcode,
                description: "Simulator runtimes and app data"
            ))
        }

        return result
    }

    private func scanIOSBackups() async -> [CleanupItem] {
        let backupPath = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MobileSync/Backup").path
        let size = await shell.directorySize(at: backupPath)
        guard size > 0 else { return [] }
        return [CleanupItem(
            name:        "iOS Device Backups",
            path:        backupPath,
            sizeBytes:   size,
            category:    .iosBackup,
            description: "iTunes/Finder backups stored on this Mac"
        )]
    }

    private func dnsCacheItem() -> CleanupItem {
        CleanupItem(
            name:        "DNS Cache",
            path:        "dns://flush",
            sizeBytes:   0,
            category:    .dns,
            description: "Flush the DNS resolver cache — fixes connectivity glitches"
        )
    }
}
