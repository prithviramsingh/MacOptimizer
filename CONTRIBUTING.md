# Contributing to MacOptimizer

Thanks for your interest. Here's how to contribute.

## Reporting bugs / requesting features

Open a GitHub Issue using the appropriate template. Include reproduction steps and macOS version for bugs.

## Submitting code changes

1. **Fork** the repo and create a branch off `main`.
2. **Build** to confirm baseline works: `./run.sh`
3. **Make your change.** Keep it focused — one thing per PR.
4. **Follow the design system** — never use raw `Color` literals, spacing numbers, or font sizes. Use `ThemeColors`, `DS.Space`, `AppFont` (see `CLAUDE.md` for details).
5. **Test manually** on macOS 13+.
6. **Open a PR** against `main`. Fill out the PR template.

## Code style

- Match surrounding SwiftUI patterns.
- No speculative abstractions — solve the stated problem, nothing more.
- Shell commands go through `ShellRunner.shared`, off main thread.

## Review process

All PRs require approval before merge. I aim to review within a few days. Feedback will be specific and actionable.

## Questions?

Open an issue with the `question` label.
