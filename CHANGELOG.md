# Changelog

All notable changes to **Fuzzy Quit** are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-09

### Added

- Bash `quit` driver with macOS (`.app`, AppleScript) and Linux process-focused flows.
- Graduated signals (SIGINT → SIGTERM → SIGKILL), dry-run, fzf/tty pickers.
- MIT license, shellcheck + tests, GitHub Actions (macOS + Linux), Docker/Make local Linux parity.
- Homebrew install via [`mlevin2/tap`](https://github.com/mlevin2/homebrew-tap).

[0.1.0]: https://github.com/mlevin2/fuzzy-quit/releases/tag/v0.1.0
