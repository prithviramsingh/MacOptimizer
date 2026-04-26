import SwiftUI

struct ProcessesView: View {
    @Environment(\.themeColors)       private var colors
    @Environment(\.processKnowledgeDB) private var knowledgeDB
    @EnvironmentObject private var processMonitor: ProcessMonitor

    @State private var searchText   = ""
    @State private var filter       = ProcessFilter.all
    @State private var sortKey      = SortKey.cpu
    @State private var sortAsc      = false
    @State private var selected: ProcessSnapshot? = nil
    @State private var killTarget: ProcessSnapshot? = nil

    enum ProcessFilter: String, CaseIterable {
        case all = "All", hogs = "Hogs", user = "User", system = "System"
    }

    enum SortKey: String {
        case name, pid, mem, cpu
    }

    // MARK: - Filtered / sorted list

    private var displayed: [ProcessSnapshot] {
        var base = processMonitor.processes
        if !searchText.isEmpty {
            base = base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        switch filter {
        case .all:    break
        case .hogs:   base = base.filter(\.isResourceHog)
        case .user:   base = base.filter { $0.user != "root" }
        case .system: base = base.filter { $0.user == "root" }
        }
        base.sort { a, b in
            let result: Bool
            switch sortKey {
            case .name: result = a.name < b.name
            case .pid:  result = a.pid  < b.pid
            case .mem:  result = a.memoryMB  > b.memoryMB
            case .cpu:  result = a.cpuPercent > b.cpuPercent
            }
            return sortAsc ? !result : result
        }
        return base
    }

    // MARK: - Body

    var body: some View {
        HSplitView {
            // Main table area
            VStack(spacing: 0) {
                headerArea
                Rectangle().fill(colors.ink8).frame(height: 1)
                columnHeaders
                Rectangle().fill(colors.ink8).frame(height: 1)
                scrollArea
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            // Detail sidebar
            if let proc = selected {
                detailPanel(proc)
                    .frame(minWidth: 260, idealWidth: DS.Size.detailWidth, maxWidth: 480)
            }
        }
        .background(colors.paper)
        .alert("Kill \(killTarget?.name ?? "process")?", isPresented: Binding(
            get: { killTarget != nil },
            set: { if !$0 { killTarget = nil } }
        )) {
            Button("Cancel", role: .cancel) { killTarget = nil }
            Button("Kill", role: .destructive) {
                guard let p = killTarget else { return }
                killTarget = nil
                if selected?.pid == p.pid { selected = nil }
                Task { await processMonitor.killProcess(p.pid) }
            }
        } message: {
            Text("Sending SIGKILL to \(killTarget?.name ?? "") (PID \(killTarget?.pid ?? 0)). Unsaved work will be lost.")
        }
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs + 2) {
            HStack(alignment: .firstTextBaseline) {
                DSEyebrow("Processes · Live")
                Spacer().frame(width: DS.Space.sm)
                Text(String(format: "%d processes", processMonitor.processes.count))
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(colors.ink)
                Text("·")
                    .foregroundStyle(colors.ink30)
                Text("\(processMonitor.resourceHogs.count) hogs")
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundStyle(processMonitor.resourceHogs.isEmpty ? colors.good : colors.accent)
                    .italic()
                Spacer()
                DSBtn("Refresh", variant: .ghost, small: true) {
                    Task { await processMonitor.refresh() }
                }
            }

            HStack(spacing: DS.Space.sm) {
                // Search
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(colors.ink40)
                    TextField("Search processes…", text: $searchText)
                        .font(AppFont.bodyUI)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, DS.Space.sm + 2)
                .padding(.vertical, DS.Space.xs + 2)
                .background(colors.ink5)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(colors.ink10, lineWidth: 1)
                )

                // Filter tabs
                HStack(spacing: 2) {
                    ForEach(ProcessFilter.allCases, id: \.self) { f in
                        filterTab(f)
                    }
                }
                .padding(3)
                .background(colors.ink8)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.xs + 2)
        .background(colors.surface)
    }

    private func filterTab(_ f: ProcessFilter) -> some View {
        let active = filter == f
        return Button {
            withAnimation(.easeInOut(duration: 0.14)) { filter = f }
        } label: {
            Text(f.rawValue)
                .font(AppFont.ui(12, weight: .semibold))
                .foregroundStyle(active ? colors.ink : colors.ink50)
                .padding(.horizontal, DS.Space.sm + 2)
                .padding(.vertical, 5)
                .background(active ? colors.surface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Table

    private var scrollArea: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayed) { proc in
                    processRow(proc)
                    Divider()
                        .padding(.leading, DS.Space.lg)
                        .opacity(0.4)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.paper)
    }

    // Column widths must match processRow exactly:
    // dot=6 + pad=2 = 8px offset, then name fills, then PID=56, Mem=74, CPU=56, Bar=56, chevron≈10
    // HStack spacing = DS.Space.sm = 14 between each item
    private var columnHeaders: some View {
        HStack(spacing: DS.Space.sm) {
            // Offset for status dot (6px) + trailing pad (2px)
            Color.clear.frame(width: 8, height: 0)

            sortHeader("Process", key: .name)

            sortHeader("PID", key: .pid, width: 56)
            sortHeader("Mem", key: .mem, width: 74)
            sortHeader("CPU", key: .cpu, width: 56)

            // Placeholder for bar (56) + chevron (10)
            Color.clear.frame(width: 56 + DS.Space.sm + 10, height: 0)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, 4)
        .background(colors.surfaceDeep)
    }

    private func sortHeader(_ label: String, key: SortKey, width: CGFloat? = nil) -> some View {
        Button {
            if sortKey == key { sortAsc.toggle() } else { sortKey = key; sortAsc = false }
        } label: {
            HStack(spacing: 3) {
                Text(label)
                    .font(AppFont.captionUI)
                    .foregroundStyle(sortKey == key ? colors.ink : colors.ink50)
                if sortKey == key {
                    Image(systemName: sortAsc ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(colors.ink50)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: .trailing)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private func processRow(_ proc: ProcessSnapshot) -> some View {
        let isSelected = selected?.pid == proc.pid
        let isHog = proc.isResourceHog

        return HStack(spacing: DS.Space.sm) {
            // Status dot
            Circle()
                .fill(isHog ? colors.accent : colors.ink15)
                .frame(width: 6, height: 6)
                .padding(.trailing, 2)

            // Name
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: DS.Space.xs) {
                    Text(knowledgeDB[proc.name]?.displayName ?? proc.name)
                        .font(AppFont.ui(13, weight: isHog ? .semibold : .regular))
                        .foregroundStyle(colors.ink)
                        .lineLimit(1)
                    if isHog {
                        DSChip("hog", tone: .accent)
                    }
                }
                Text(proc.user)
                    .font(AppFont.monoCaption)
                    .foregroundStyle(colors.ink40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // PID
            Text("\(proc.pid)")
                .font(AppFont.monoCaption)
                .foregroundStyle(colors.ink50)
                .frame(width: 56, alignment: .trailing)

            // Mem
            Text(fmtMB(proc.memoryMB))
                .font(AppFont.monoCaption)
                .foregroundStyle(proc.memoryMB > 500 ? colors.accent : colors.ink60)
                .frame(width: 74, alignment: .trailing)

            // CPU
            Text(String(format: "%.1f%%", proc.cpuPercent))
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(proc.cpuPercent > 20 ? colors.accent : colors.ink70)
                .frame(width: 56, alignment: .trailing)

            // Bar + chevron
            DSBar(value: proc.cpuPercent, maxValue: 100, height: 3)
                .frame(width: 56)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(colors.ink30)
                .rotationEffect(.degrees(isSelected ? 90 : 0))
                .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm + 1)
        .background(isSelected ? colors.accent5 : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.16)) {
                selected = (selected?.pid == proc.pid) ? nil : proc
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    // MARK: - Detail Panel

    private func detailPanel(_ proc: ProcessSnapshot) -> some View {
        let knowledge = knowledgeDB[proc.name]

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                DSEyebrow("Process Detail")
                Spacer()
                Button {
                    withAnimation { selected = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(colors.ink30)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Space.lg)

            Divider().opacity(0.5)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xl) {
                    // Hero stats
                    HStack(spacing: DS.Space.xl) {
                        VStack(alignment: .leading, spacing: 4) {
                            DSEyebrow("CPU")
                            Text(String(format: "%.1f%%", proc.cpuPercent))
                                .font(AppFont.heroMedium)
                                .foregroundStyle(proc.cpuPercent > 20 ? colors.accent : colors.ink)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            DSEyebrow("Memory")
                            Text(fmtMB(proc.memoryMB))
                                .font(AppFont.heroMedium)
                                .foregroundStyle(proc.memoryMB > 500 ? colors.accent : colors.ink)
                        }
                    }

                    // Info
                    VStack(alignment: .leading, spacing: DS.Space.sm) {
                        infoRow(label: "PID",  value: "\(proc.pid)")
                        infoRow(label: "User", value: proc.user)
                        infoRow(label: "Name", value: proc.name)
                    }

                    // Knowledge note
                    if let desc = knowledge?.description {
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            DSEyebrow("What this does")
                            Text(desc)
                                .font(AppFont.bodyUI)
                                .foregroundStyle(colors.ink70)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Actions
                    if let high = knowledge?.highCPUSuggestion, proc.cpuPercent > 15 {
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            DSEyebrow("Fix Ideas")
                            Text(high)
                                .font(AppFont.captionUI)
                                .foregroundStyle(colors.ink60)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if knowledge?.safeToKill == true {
                        DSBtn("Quit Process", variant: .danger) {
                            killTarget = proc
                        }
                    } else {
                        Text("System process — cannot quit")
                            .font(AppFont.captionUI)
                            .foregroundStyle(colors.ink40)
                            .italic()
                    }
                }
                .padding(DS.Space.lg)
            }
        }
        .background(colors.surface)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFont.captionUI)
                .foregroundStyle(colors.ink40)
                .frame(width: 40, alignment: .leading)
            Text(value)
                .font(AppFont.monoCaption)
                .foregroundStyle(colors.ink70)
        }
    }

    // MARK: - Formatters

    private func fmtMB(_ mb: Double) -> String {
        mb >= 1024 ? String(format: "%.1f GB", mb / 1024) : String(format: "%.0f MB", mb)
    }
}
