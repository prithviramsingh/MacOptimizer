import SwiftUI

struct CleanupView: View {
    @Environment(\.themeColors) private var colors
    @EnvironmentObject private var cleaner: SystemCleaner

    @State private var showConfirm = false
    @State private var showLog     = false

    // MARK: - Derived

    private var phase: CleanupPhase {
        if cleaner.isCleaning         { return .cleaning }
        if cleaner.isScanning         { return .scanning }
        if !cleaner.log.isEmpty       { return .done }
        if !cleaner.items.isEmpty     { return .scanned }
        return .idle
    }

    private enum CleanupPhase { case idle, scanning, scanned, cleaning, done }

    private var headline: (String, String) {
        switch phase {
        case .idle:     return ("Reclaim ", "space safely")
        case .scanning: return ("Scanning ", "your disk…")
        case .scanned:
            let gb = Double(cleaner.selectedSize) / 1_000_000_000
            return (String(format: "%.1f GB", gb), " ready to clean")
        case .cleaning: return ("Cleaning ", "selected items…")
        case .done:
            let gb = Double(cleaner.cleanedBytes) / 1_000_000_000
            return (String(format: "%.1f GB", gb), " reclaimed")
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                headerSection
                if phase == .scanning || phase == .cleaning { progressCard }
                if phase == .scanned || phase == .done      { summaryCard }
                if phase == .scanned                        { itemList }
            }
            .padding(DS.Space.xl)
        }
        .background(colors.paper)
        .alert("Clean Now?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) { Task { await cleaner.clean() } }
        } message: {
            Text("This will permanently delete the selected items. \(fmtBytes(cleaner.selectedSize)) will be freed.")
        }
        .sheet(isPresented: $showLog) {
            logSheet
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            DSEyebrow("Cleanup")

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(headline.0)
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(colors.ink)
                    .italic(phase == .scanned || phase == .done)
                Text(headline.1)
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(phase == .scanned || phase == .done ? colors.accent : colors.ink)
            }

            HStack(spacing: DS.Space.sm) {
                // Dry run toggle
                HStack(spacing: DS.Space.xs) {
                    Toggle("Dry Run", isOn: $cleaner.dryRun)
                        .toggleStyle(DSToggleStyle())
                        .labelsHidden()
                    Text("Dry Run")
                        .font(AppFont.captionUI)
                        .foregroundStyle(colors.ink60)
                }

                Spacer()

                // Actions
                switch phase {
                case .idle:
                    DSBtn("Scan Disk", variant: .primary, small: true) {
                        Task { await cleaner.scan() }
                    }
                case .scanning, .cleaning:
                    ProgressView()
                        .scaleEffect(0.7)
                case .scanned:
                    DSBtn("Rescan", variant: .ghost, small: true) {
                        Task { await cleaner.scan() }
                    }
                    DSBtn(cleaner.dryRun ? "Preview Cleanup" : "Clean Now", variant: cleaner.dryRun ? .solid : .danger, small: true) {
                        if cleaner.dryRun { Task { await cleaner.clean() } }
                        else { showConfirm = true }
                    }
                case .done:
                    DSBtn("View Log", variant: .ghost, small: true) { showLog = true }
                    DSBtn("Scan Again", variant: .solid, small: true) {
                        Task { await cleaner.scan() }
                    }
                }
            }
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        DSCard(padding: DS.Space.lg) {
            VStack(alignment: .leading, spacing: DS.Space.sm) {
                DSEyebrow(phase == .scanning ? "Scanning" : "Cleaning")
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
    }

    // MARK: - Summary Card (inverted)

    private var summaryCard: some View {
        DSCard(padding: DS.Space.lg, inverted: true) {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    DSEyebrow(phase == .done ? "Total Reclaimed" : "Ready to Clean")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(fmtBytesHero(phase == .done ? cleaner.cleanedBytes : cleaner.selectedSize))
                            .font(.system(size: 56, weight: .regular, design: .serif))
                        Text(fmtBytesUnit(phase == .done ? cleaner.cleanedBytes : cleaner.selectedSize))
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .opacity(0.6)
                    }
                }

                // Category bar chart
                if !cleaner.items.isEmpty {
                    categoryChart
                }
            }
        }
    }

    private var categoryChart: some View {
        let categories = Dictionary(grouping: cleaner.items, by: \.category)
        let maxBytes = categories.values.map { $0.reduce(0) { $0 + $1.sizeBytes } }.max() ?? 1

        return HStack(alignment: .bottom, spacing: DS.Space.sm) {
            ForEach(CleanupItem.Category.allCases, id: \.self) { cat in
                let items = categories[cat] ?? []
                let bytes = items.reduce(0) { $0 + $1.sizeBytes }
                if bytes > 0 {
                    VStack(spacing: DS.Space.xs) {
                        Text(fmtBytes(bytes))
                            .font(AppFont.monoCaption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(.white.opacity(0.25))
                            .frame(height: max(8, 80 * CGFloat(bytes) / CGFloat(maxBytes)))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: bytes)

                        Text(cat.rawValue)
                            .font(AppFont.captionUI)
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 130)
    }

    // MARK: - Item List

    private var itemList: some View {
        DSCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Button("Select All")   { cleaner.items.indices.forEach { cleaner.items[$0].isSelected = true } }
                        .buttonStyle(.plain)
                        .font(AppFont.captionUI)
                        .foregroundStyle(colors.accent)
                    Text("·")
                        .foregroundStyle(colors.ink30)
                    Button("Deselect All") { cleaner.items.indices.forEach { cleaner.items[$0].isSelected = false } }
                        .buttonStyle(.plain)
                        .font(AppFont.captionUI)
                        .foregroundStyle(colors.ink50)
                    Spacer()
                    Text("\(cleaner.selectedItems.count) selected · \(fmtBytes(cleaner.selectedSize))")
                        .font(AppFont.monoCaption)
                        .foregroundStyle(colors.ink50)
                }
                .padding(.horizontal, DS.Space.lg)
                .padding(.vertical, DS.Space.sm + 2)
                .background(colors.surfaceDeep)

                Divider().opacity(0.5)

                ForEach($cleaner.items) { $item in
                    cleanupItemRow(item: $item)
                    Divider().padding(.leading, DS.Space.lg).opacity(0.4)
                }
            }
        }
    }

    private func cleanupItemRow(item: Binding<CleanupItem>) -> some View {
        HStack(spacing: DS.Space.md) {
            // Checkbox
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(item.wrappedValue.isSelected ? colors.accent : colors.ink8)
                    .frame(width: 18, height: 18)
                if item.wrappedValue.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .onTapGesture { item.wrappedValue.isSelected.toggle() }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DS.Space.xs) {
                    Text(item.wrappedValue.name)
                        .font(AppFont.ui(13, weight: .medium))
                        .foregroundStyle(colors.ink)
                    DSChip(item.wrappedValue.category.rawValue, tone: .neutral)
                }
                Text(item.wrappedValue.path)
                    .font(AppFont.monoCaption)
                    .foregroundStyle(colors.ink40)
                    .lineLimit(1)
                Text(item.wrappedValue.description)
                    .font(AppFont.captionUI)
                    .foregroundStyle(colors.ink50)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Size
            Text(item.wrappedValue.formattedSize)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(colors.ink70)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm + 2)
    }

    // MARK: - Log Sheet

    private var logSheet: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                Text("Cleanup Log")
                    .font(.system(size: 18, weight: .regular, design: .serif))
                Spacer()
                Button("Done") { showLog = false }
                    .buttonStyle(.borderedProminent)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(cleaner.log, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(line.hasPrefix("✓") ? Color.green :
                                             line.hasPrefix("✗") ? Color.red : Color.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Formatters

    private func fmtBytes(_ bytes: Int64) -> String {
        let fmt = ByteCountFormatter()
        fmt.countStyle = .file
        return fmt.string(fromByteCount: bytes)
    }

    private func fmtBytesHero(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 1 { return String(format: "%.1f", gb) }
        let mb = Double(bytes) / 1_000_000
        return String(format: "%.0f", mb)
    }

    private func fmtBytesUnit(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        return gb >= 1 ? "GB" : "MB"
    }
}
