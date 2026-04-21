import SwiftUI

struct ProcessesView: View {
    @EnvironmentObject var processMonitor: ProcessMonitor
    @EnvironmentObject var knowledgeBase:  KnowledgeBase

    @State private var searchText       = ""
    @State private var sortOrder        = SortOrder.cpu
    @State private var killTarget: ProcessSnapshot? = nil

    enum SortOrder: String, CaseIterable {
        case cpu    = "CPU"
        case memory = "Memory"
        case name   = "Name"
    }

    var filteredProcesses: [ProcessSnapshot] {
        let base = searchText.isEmpty
            ? processMonitor.processes
            : processMonitor.processes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        switch sortOrder {
        case .cpu:    return base.sorted { $0.cpuPercent > $1.cpuPercent }
        case .memory: return base.sorted { $0.memoryMB   > $1.memoryMB   }
        case .name:   return base.sorted { $0.name       < $1.name       }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar row
            HStack {
                Text("Processes")
                    .font(.largeTitle).bold()
                Spacer()
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
                Button("Refresh") {
                    Task { await processMonitor.refresh() }
                }
            }
            .padding()

            TextField("Search processes…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 8)

            // Column headers
            HStack {
                Text("Process")   .frame(minWidth: 160, alignment: .leading)
                Spacer()
                Text("PID")       .frame(width: 60,  alignment: .trailing)
                Text("CPU")       .frame(width: 70,  alignment: .trailing)
                Text("Memory")    .frame(width: 80,  alignment: .trailing)
                Text("User")      .frame(width: 90,  alignment: .trailing)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 4)

            Divider()

            List(filteredProcesses) { process in
                ProcessRow(
                    process:   process,
                    knowledge: knowledgeBase.db[process.name]
                )
                .contextMenu {
                    Button(role: .destructive) { killTarget = process } label: {
                        Label("Kill Process", systemImage: "xmark.circle")
                    }
                    Divider()
                    Button("Copy PID") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("\(process.pid)", forType: .string)
                    }
                    Button("Copy Name") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(process.name, forType: .string)
                    }
                }
            }
            .listStyle(.plain)
        }
        .alert("Kill \(killTarget?.name ?? "process")?", isPresented: Binding(
            get:  { killTarget != nil },
            set:  { if !$0 { killTarget = nil } }
        )) {
            Button("Cancel", role: .cancel) { killTarget = nil }
            Button("Kill", role: .destructive) {
                guard let p = killTarget else { return }
                killTarget = nil
                Task { await processMonitor.killProcess(p.pid) }
            }
        } message: {
            Text("Sending SIGKILL to \(killTarget?.name ?? "") (PID \(killTarget?.pid ?? 0)). Unsaved work in that app will be lost.")
        }
        .onChange(of: processMonitor.processes) { _ in
            knowledgeBase.analyze(
                processes: processMonitor.processes,
                histories: processMonitor.processHistories
            )
        }
    }
}

struct ProcessRow: View {
    let process:   ProcessSnapshot
    let knowledge: ProcessKnowledge?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(knowledge?.displayName ?? process.name)
                        .fontWeight(process.isResourceHog ? .semibold : .regular)
                    if process.isResourceHog {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                if let desc = knowledge?.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 160, alignment: .leading)

            Spacer()

            Text("\(process.pid)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)

            Text(String(format: "%.1f%%", process.cpuPercent))
                .foregroundColor(cpuColor(process.cpuPercent))
                .frame(width: 70, alignment: .trailing)

            Text(String(format: "%.0f MB", process.memoryMB))
                .foregroundColor(memColor(process.memoryMB))
                .frame(width: 80, alignment: .trailing)

            Text(process.user)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }

    private func cpuColor(_ v: Double) -> Color {
        v > 50 ? .red : v > 20 ? .orange : .primary
    }
    private func memColor(_ v: Double) -> Color {
        v > 1000 ? .red : v > 500 ? .orange : .primary
    }
}
