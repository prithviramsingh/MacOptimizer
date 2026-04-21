import Foundation

struct CleanupItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    var sizeBytes: Int64
    let category: Category
    let description: String
    var isSelected: Bool = true

    enum Category: String, CaseIterable {
        case userCache  = "User Cache"
        case logs       = "Logs"
        case xcode      = "Xcode"
        case iosBackup  = "iOS Backups"
        case dns        = "DNS Cache"
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}
