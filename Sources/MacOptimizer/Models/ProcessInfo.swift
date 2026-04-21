import Foundation

struct ProcessSnapshot: Identifiable, Hashable {
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memoryMB: Double
    let user: String

    var id: Int32 { pid }

    var isResourceHog: Bool {
        cpuPercent > 20 || memoryMB > 500
    }
}

struct ProcessHistory {
    let name: String
    var samples: [(date: Date, cpu: Double, memory: Double)] = []
    private let maxSamples = 60  // 5 minutes at 5s intervals

    init(name: String) {
        self.name = name
    }

    mutating func addSample(cpu: Double, memory: Double) {
        samples.append((Date(), cpu, memory))
        if samples.count > maxSamples {
            samples.removeFirst()
        }
    }

    var avgCPU: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.cpu).reduce(0, +) / Double(samples.count)
    }

    var peakCPU: Double {
        samples.map(\.cpu).max() ?? 0
    }

    var avgMemory: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.memory).reduce(0, +) / Double(samples.count)
    }
}
