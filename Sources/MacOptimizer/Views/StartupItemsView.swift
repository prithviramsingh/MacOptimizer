import SwiftUI

struct StartupItemsView: View {
    @EnvironmentObject var startupService: StartupItemsService

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Startup Items")
                    .font(.largeTitle).bold()
                Spacer()
                Button("Refresh") {
                    Task { await startupService.load() }
                }
            }
            .padding()

            Text("Programs listed below run automatically at login. Disabling unnecessary ones speeds up boot time and frees background resources.")
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            if startupService.isLoading {
                ProgressView("Loading startup items…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if startupService.items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary)
                    Text("No startup items found")
                        .foregroundColor(.secondary)
                    Button("Load Startup Items") {
                        Task { await startupService.load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                List {
                    ForEach(StartupItem.Source.allCases, id: \.self) { source in
                        let sourceItems = startupService.items.filter { $0.source == source }
                        if !sourceItems.isEmpty {
                            Section(header: Text(source.rawValue).textCase(.none)) {
                                ForEach(sourceItems) { item in
                                    StartupItemRow(item: item) {
                                        Task { await startupService.toggle(item) }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("Changes take effect on next login. System daemons may require administrator privileges to modify.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
}

struct StartupItemRow: View {
    let item:     StartupItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.isEnabled ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.programPath)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.isEnabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundColor(item.isEnabled ? .green : .secondary)
                .frame(width: 55, alignment: .trailing)

            Button(item.isEnabled ? "Disable" : "Enable") {
                onToggle()
            }
            .buttonStyle(.bordered)
            .tint(item.isEnabled ? .red : .green)
            .frame(width: 75)
        }
        .padding(.vertical, 2)
    }
}
