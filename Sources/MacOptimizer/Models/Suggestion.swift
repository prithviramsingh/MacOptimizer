import Foundation

struct Suggestion: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let severity: Severity
    let category: Category
    let actionLabel: String?

    enum Severity: String {
        case critical = "Critical"
        case warning  = "Warning"
        case info     = "Info"
    }

    enum Category: String {
        case process  = "Process"
        case disk     = "Disk"
        case startup  = "Startup"
        case memory   = "Memory"
        case thermal  = "Thermal"
    }
}
