# MacOptimizer

> A free, native SwiftUI app that keeps your Mac fast — real-time process monitoring, system cleanup, startup management, and smart suggestions, all in one place.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue?style=flat-square&logo=apple)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen?style=flat-square)
![License: MIT](https://img.shields.io/badge/license-MIT-purple?style=flat-square)

---

## Overview

MacOptimizer is a lightweight, fully native macOS utility built entirely with **Swift** and **SwiftUI**. It has zero third-party dependencies — everything runs locally on your machine with no network calls, no analytics, and no accounts required.

The app is structured around five focused modules accessible from a clean sidebar:

| Module | What it does |
|---|---|
| **Dashboard** | At-a-glance system health: active processes, resource hogs, and suggestion count |
| **Processes** | Full sortable process list with live CPU & RAM readings |
| **Cleanup** | Scans caches, logs, Xcode artefacts, and iOS backups; cleans safely |
| **Startup Items** | Lists all LaunchAgents and lets you toggle them without leaving the app |
| **Suggestions** | Smart, ranked fix cards generated from a built-in process knowledge base |

---

## Features

### Real-Time Process Monitor

MacOptimizer polls `ps` **every 5 seconds** and tracks CPU and memory usage for every running process. It maintains a rolling history of samples per process and automatically flags **resource hogs** — any process exceeding **20 % CPU** or **500 MB RAM**.

- Live updating process list with name, PID, CPU %, and RAM (MB)
- Per-process history used to detect **sustained** high CPU, not just momentary spikes
- Resource hog detection with configurable thresholds
- Kill button available for processes marked safe to terminate

### System Cleanup

The cleanup module scans common sources of disk waste and presents a summary before touching anything. **Dry-run mode is on by default** — you review what will be removed before committing.

Scanned locations:

| Target | Path |
|---|---|
| User caches | `~/Library/Caches` |
| System logs | `~/Library/Logs` |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` |
| iOS Simulators | `~/Library/Developer/CoreSimulator/Devices` |
| iOS device backups | `~/Library/Application Support/MobileSync/Backup` |
| DNS cache | Flushed via `dscacheutil -flushcache` |

### Startup Item Manager

Reads all LaunchAgents from both user and system directories:

- `~/Library/LaunchAgents` — user-level agents
- `/Library/LaunchAgents` — system-level agents

Each item is shown with its label and current enabled/disabled state. Toggle any item on or off using `launchctl load` / `launchctl unload` without opening Terminal or System Settings.

### Smart Suggestions Engine

The Suggestions view cross-references live process data against the built-in knowledge base every monitoring cycle. It surfaces up to 25 ranked cards across three severity levels:

| Severity | Trigger |
|---|---|
| 🔴 **Critical** | > 60 % CPU or > 1 200 MB RAM |
| 🟠 **Warning** | > 15 % CPU or > 400 MB RAM |
| 🔵 **Info** | Sustained average > 12 % CPU across 6+ samples |

Each card shows the process name, usage figure, a plain-English explanation of what the process does, and a **specific fix** tailored to that process.

### Process Knowledge Base

MacOptimizer ships with expert knowledge about the most common macOS performance culprits:

| Process | Display Name | Notes |
|---|---|---|
| `kernel_task` | macOS Kernel | High CPU = thermal throttling; cool your Mac |
| `mds_stores` | Spotlight Indexer | Add large drives to Spotlight privacy exclusion list |
| `mds` | Spotlight Metadata Server | Related to Spotlight indexing cycle |
| `WindowServer` | Window Server | Reduce Motion & Transparency in Accessibility settings |
| `coreaudiod` | Core Audio Daemon | `sudo killall coreaudiod` resets audio without a reboot |
| `Google Chrome Helper` | Chrome Renderer | Use Chrome's built-in Task Manager (⇧Esc) to find the offending tab |
| `Google Chrome Helper (Renderer)` | Chrome Renderer | Per-tab renderer process |
| `com.apple.WebKit.WebContent` | Safari Web Content | Safari's tab renderer |
| `cloudd` | iCloud Daemon | Wait for sync; sign out/in if it runs for hours |
| `backupd` | Time Machine | Pause with `tmutil stopbackup`; schedule off-hours |
| `softwareupdated` | Software Update | Pause in System Settings → Software Update |
| `mediaanalysisd` | Media Analysis | Quit Photos to pause library analysis |
| `Xcode` | Xcode | Disable background indexing; close unused simulators |
| `Slack` | Slack | Quit & relaunch or use the web version |
| `node` | Node.js | Check for runaway watch/build scripts in Terminal |
| `com.apple.MobileSMS` | Messages | Restart the app; may be syncing a large history |

---

## Architecture

```
MacOptimizer/
├── Package.swift                    # Swift Package Manifest — macOS 13+, zero deps
├── MacOptimizer.entitlements        # App sandbox entitlements
├── run.sh                           # Build & run convenience script
├── distribute.sh                    # Packages a .app bundle for distribution
├── docs/                            # GitHub Pages site (index.html)
└── Sources/MacOptimizer/
    ├── MacOptimizerApp.swift        # @main — injects all EnvironmentObjects
    ├── ContentView.swift            # NavigationSplitView with 5 sidebar items
    ├── Models/
    │   ├── ProcessInfo.swift        # ProcessSnapshot + ProcessHistory
    │   ├── CleanupItem.swift        # Represents a scannable cleanup target
    │   └── Suggestion.swift         # Severity-ranked suggestion model
    ├── Services/
    │   ├── ShellRunner.swift        # Async shell command execution wrapper
    │   ├── ProcessMonitor.swift     # Polls ps every 5s, tracks per-process history
    │   ├── SystemCleaner.swift      # Scans & cleans caches / logs / DerivedData
    │   ├── StartupItemsService.swift# Reads LaunchAgents, toggles via launchctl
    │   └── KnowledgeBase.swift      # 13+ process entries, generates Suggestion list
    └── Views/
        ├── DashboardView.swift      # Stat cards + top consumers + suggestion preview
        ├── ProcessesView.swift      # Full sortable process list
        ├── CleanupView.swift        # Scan results + dry-run / clean actions
        ├── StartupItemsView.swift   # Toggle launch agents on/off
        └── SuggestionsView.swift    # Severity-ranked suggestion cards
```

The layering is: **Services** produce data → **Models** represent it → **Views** consume it via `@EnvironmentObject`. Adding a new module means adding a service, a model (if needed), and a view — the pattern is consistent throughout.

---

## Requirements

- macOS 13 Ventura or later (Apple Silicon & Intel)
- Xcode 15+ — for IDE build
- Swift 5.9+ toolchain — for terminal build

---

## Installation

### Option 1 — Terminal

```bash
# Clone
git clone https://github.com/prithviramsingh/MacOptimizer.git
cd MacOptimizer

# Build (release)
swift build -c release

# Run
./run.sh
# or directly:
.build/release/MacOptimizer
```

### Option 2 — Xcode

1. Clone the repository
2. Open **Xcode 15+** → **File → Open** → select `Package.swift`
3. Wait for Swift Package indexing to complete
4. Select the `MacOptimizer` scheme → press **⌘R**

### Option 3 — Distributable .app

```bash
chmod +x distribute.sh
./distribute.sh
```

This creates `MacOptimizer.app` in the project root. Drag it into `/Applications` to install system-wide.

> **Note:** When the app first accesses `/Library/LaunchAgents` or runs `launchctl`, macOS may prompt for permission. This is a standard OS security prompt — granting it gives the app access only to those specific paths.

---

## FAQ

**Is it safe?**
The Cleanup module always starts in dry-run mode and reports what it *would* delete before acting. System-critical processes (`kernel_task`, `WindowServer`, etc.) are never killable from within the app.

**Does it phone home?**
No. Zero network calls. Everything runs locally. The source is open — verify it yourself.

**How do I add a process to the knowledge base?**
Open `Sources/MacOptimizer/Services/KnowledgeBase.swift` and add an entry to the `db` dictionary using the `ProcessKnowledge` struct. Pull requests are very welcome.

**Why is my fan spinning even though MacOptimizer says the top process is only at 30 % CPU?**
Multiple processes each at moderate CPU add up. Check the full Processes list — the sum of all usage across cores is what drives heat, not any single entry.

---

## Contributing

1. Fork the repo and create a branch: `git checkout -b feature/my-change`
2. Make your changes — follow the existing services → models → views pattern
3. Build and test: `swift build`
4. Open a pull request with a clear description of what changed and why

All contributions are welcome: new knowledge base entries, additional cleanup targets, UI improvements, and bug fixes.

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

<p align="center">
  Built with Swift &amp; SwiftUI &nbsp;·&nbsp; macOS 13+ &nbsp;·&nbsp; Zero dependencies<br/>
  <a href="https://prithviramsingh.github.io/MacOptimizer/">Website</a> &nbsp;·&nbsp;
  <a href="https://github.com/prithviramsingh/MacOptimizer/issues">Report a Bug</a>
</p>
