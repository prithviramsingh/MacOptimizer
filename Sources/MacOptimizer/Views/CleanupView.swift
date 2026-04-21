import SwiftUI

struct CleanupView: View {
    @EnvironmentObject var cleaner: SystemCleaner

    @State private var showConfirm = false
    @State private var showLog     = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("System Cleanup")
                    .font(.largeTitle).bold()
                Spacer()
                Toggle(isOn: $cleaner.dryRun) {
                    Label("Dry Run", systemImage: "eye")
                }
                .toggleStyle(.switch)
                .help("Preview what would be deleted without actually removing anything")
            }
            .padding()

            Group {
                if cleaner.isScanning {
                    VStack(spacing: 12) {
                        ProgressView("Scanning your system…")
                        Text("This may take a few seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if cleaner.items.isEmpty {
                    emptyState

                } else {
                    itemList
                }
            }
        }
        .alert("Confirm Cleanup", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Files", role: .destructive) {
                Task {
                    await cleaner.clean()
                    showLog = true
                }
            }
        } message: {
            Text("This permanently deletes \(ByteCountFormatter.string(fromByteCount: cleaner.selectedSize, countStyle: .file)). This cannot be undone.")
        }
        .sheet(isPresented: $showLog) {
            CleanupLogSheet(logs: cleaner.log)
        }
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 52))
                .foregroundColor(.secondary)
            Text("Scan your system to find cleanable files")
                .foregroundColor(.secondary)
            Button("Start Scan") {
                Task { await cleaner.scan() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var itemList: some View {
        VStack(spacing: 0) {
            // Selection toolbar
            HStack {
                Button("Select All")   { for i in cleaner.items.indices { cleaner.items[i].isSelected = true  } }
                Button("Deselect All") { for i in cleaner.items.indices { cleaner.items[i].isSelected = false } }
                Spacer()
                Text("Selected: \(ByteCountFormatter.string(fromByteCount: cleaner.selectedSize, countStyle: .file))")
                    .fontWeight(.semibold)
                Button("Rescan") {
                    Task { await cleaner.scan() }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List {
                ForEach(CleanupItem.Category.allCases, id: \.self) { category in
                    let categoryItems = cleaner.items.filter { $0.category == category }
                    if !categoryItems.isEmpty {
                        Section(category.rawValue) {
                            ForEach($cleaner.items) { $item in
                                if item.category == category {
                                    CleanupItemRow(item: $item)
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            // Action bar
            HStack {
                Spacer()
                if cleaner.isCleaning {
                    ProgressView("Cleaning…")
                } else {
                    Button(cleaner.dryRun ? "Preview Cleanup" : "Clean Now") {
                        if cleaner.dryRun {
                            Task {
                                await cleaner.clean()
                                showLog = true
                            }
                        } else {
                            showConfirm = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(cleaner.dryRun ? .blue : .red)
                    .disabled(cleaner.selectedItems.isEmpty)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}

struct CleanupItemRow: View {
    @Binding var item: CleanupItem

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $item.isSelected).labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).fontWeight(.medium)
                Text(item.description)
                    .font(.caption).foregroundColor(.secondary)
                Text(item.path)
                    .font(.caption2).foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.formattedSize)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

struct CleanupLogSheet: View {
    let logs: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Cleanup Report")
                    .font(.title2).bold()
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(
                                line.hasPrefix("✓") ? .green
                                : line.hasPrefix("✗") ? .red
                                : .primary
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
        .frame(width: 540, height: 420)
    }
}
