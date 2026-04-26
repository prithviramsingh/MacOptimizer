# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Build and launch the app (debug build, no signing required)
./run.sh

# Build only
swift build

# Release build
swift build -c release

# Clean
swift package clean
```

The app requires macOS 13+. There is no test suite.

## Distribution

```bash
# Notarized DMG for distribution (requires Developer ID cert + Apple credentials)
APPLE_ID=you@example.com APP_PASSWORD=xxxx-xxxx-xxxx-xxxx ./distribute.sh
```

Output lands in `.build/distribution/MacOptimizer-1.0.0.dmg`.

## Architecture

Single-target SwiftUI app (`Sources/MacOptimizer/`). Five `@StateObject` services are created in `MacOptimizerApp` and injected as `@EnvironmentObject` into the entire view tree:

| Service | Role |
|---|---|
| `ProcessMonitor` | Polls `ps`/`top` every 5 s; vends CPU/RAM per-process snapshots and system vitals |
| `SystemCleaner` | Locates and removes caches/logs/trash; reports reclaimable bytes per category |
| `StartupItemsService` | Reads login items via `SMAppService` and LaunchAgent plists |
| `KnowledgeBase` | Static database of optimization tips mapped to `Suggestion` models |
| `ThemeManager` | Persists `AppTheme` (Paper / Graphite) to `AppStorage`; exposes `ThemeColors` |

`ContentView` owns a `NavItem` enum and routes to one of five detail views via a switch: `DashboardView`, `ProcessesView`, `CleanupView`, `StartupItemsView`, `SuggestionsView`.

## Design System (`DesignSystem/`)

All UI tokens are centralized — never use raw literals for colors, spacing, or type:

- **`ThemeColors`** — accessed via `@Environment(\.themeColors)`. Provides `paper`, `surface`, `sidebar`, `ink`, `accent`, `good`, `critical`, `warning`, and derived opacity variants (`ink8`, `accent10`, etc.). Two palettes: `.paper` (warm light) and `.graphite` (dark).
- **`DS`** — spacing (`DS.Space.sm/md/lg/xl`), corner radii (`DS.Radius.card`), and layout constants (`DS.Size.sidebarWidth`).
- **`AppFont`** — three families: `hero()` (New York serif), `ui()` (SF Pro), `mono()` (SF Mono). Use named presets (`AppFont.bodyUI`, `.captionUI`, etc.) before reaching for raw sizes.
- **`DesignSystem/Components/`** — reusable primitives: `DSCard`, `DSButton`, `DSChip`, `DSBar`, `DSRing`, `DSSparkline`, `DSToggle`, `DSVitalCard`, `DSEyebrow`, `DSPulseDot`, `SidebarView`.

When adding new UI, pull colors from `ThemeColors` (not `Color` literals), spacing from `DS.Space`, and type from `AppFont`. New views should read `@Environment(\.themeColors)` directly.

## Shell Execution

`ShellRunner.shared` wraps synchronous `Process` + `Pipe` execution. All service classes use it to run `ps`, `top`, `launchctl`, `du`, etc. Calls run off-main-thread; results are published back on `@MainActor`.


## CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

