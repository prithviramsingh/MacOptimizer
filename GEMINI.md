# MacOptimizer — Project Context

A lightweight, fully native macOS utility built with Swift and SwiftUI. It provides real-time process monitoring, system cleanup, startup item management, and intelligent performance suggestions with zero third-party dependencies.

## Project Overview

*   **Primary Purpose:** Performance optimization and system maintenance for macOS.
*   **Target Platform:** macOS 13.0 (Ventura) or later.
*   **Architecture:** Service-oriented architecture where Logic is encapsulated in **Services**, Data is represented by **Models**, and UI is handled by **SwiftUI Views**.
*   **Dependency Strategy:** Zero third-party dependencies. Uses standard macOS CLI tools (`ps`, `launchctl`, `kill`, `dscacheutil`) and native system APIs (`mach_host_self`, `FileManager`).

## Technical Stack

*   **Language:** Swift 5.9+
*   **Frameworks:** SwiftUI, Foundation, Darwin
*   **Build System:** Swift Package Manager (SPM)
*   **Toolchain:** Xcode 15+ / Swift 5.9 Toolchain

## Architecture & Key Symbols

The application state is managed by several `@StateObject` services initialized in `MacOptimizerApp.swift` and injected as `@EnvironmentObject` into the view hierarchy.

### Core Services (`Sources/MacOptimizer/Services/`)

*   **`ProcessMonitor`:** The central heartbeat. Polls `ps` every 5 seconds, calculates real-time CPU/RAM usage, and tracks per-process history to identify sustained "resource hogs."
*   **`SystemCleaner`:** Handles disk cleanup. Scans specific directories (caches, logs, Xcode data) and executes deletions. **Dry-run is default.**
*   **`StartupItemsService`:** Interfaces with `launchctl` and `~/Library/LaunchAgents` to list and toggle startup items.
*   **`KnowledgeBase`:** A local expert system mapping process names to human-readable explanations and specific fixes. Generates `Suggestion` cards.
*   **`ShellRunner`:** A thread-safe async wrapper for `Process` and `Pipe` to execute shell commands.

### Design System (`Sources/MacOptimizer/DesignSystem/`)

*   **`ThemeManager`:** Manages the toggle between "Paper" (Light) and "Graphite" (Dark) themes.
*   **`ThemeColors`:** Custom semantic color palette using hex initializers and opacity ramps.
*   **Components:** Prefix `DS` (e.g., `DSBar`, `DSRing`, `DSPulseDot`) used for all custom UI primitives.

## Commands & Development

### Building and Running

*   **Development Build & Run:**
    ```bash
    ./run.sh
    ```
    (Cleans, builds, creates a temporary `.app` bundle, and launches it).

*   **Release/Distribution Build:**
    ```bash
    ./distribute.sh
    ```
    (Requires `APPLE_ID`, `APP_PASSWORD`, and `TEAM_ID` environment variables. Performs signing, notarization, and DMG creation).

*   **Standard Swift Build:**
    ```bash
    swift build
    ```

### Development Conventions

*   **Environment Objects:** Always access services via `@EnvironmentObject` in views. Avoid singletons if possible (except `ShellRunner`).
*   **Shell Commands:** Use `ShellRunner.shared.run(...)` for all CLI interactions. Never call `Process()` directly in views.
*   **Cleanup Logic:** New cleanup targets should be added to `SystemCleaner.swift` following the `CleanupItem` model pattern.
*   **Knowledge Base:** To add a new process insight, update `KnowledgeBase.swift`'s internal dictionary.
*   **Visual Consistency:** Use `themeColors` from the environment for all styling. Avoid hardcoded `Color.white` or `Color.black`.

## Directory Structure

*   `Sources/MacOptimizer/Models/`: Plain data structures (`ProcessSnapshot`, `Suggestion`).
*   `Sources/MacOptimizer/Services/`: Business logic and system interaction.
*   `Sources/MacOptimizer/Views/`: Feature-specific views (Dashboard, Processes, etc.).
*   `Sources/MacOptimizer/DesignSystem/`: Shared UI components and theming logic.
*   `docs/`: Static React-based documentation for the project website.
