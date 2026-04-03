# quit

See **`$HOME/software/README.md`** for how this fits under `~/software` and how **`$HOME/lib`** stays the canonical path for shared shell code.

macOS helper to stop applications and command-line processes with **graduated escalation**. Each argument is classified independently as either a **GUI application** (`.app` bundle) or a **plain process**, then the appropriate ladder runs. All matching is **case-insensitive** — `quit safari`, `quit Safari`, and `quit SAFARI` all work.

## Requirements

- macOS
- Bash
- Shared logging helpers in **`$HOME/lib/common.sh`** (from the [`common-lib`](../common-lib/) project; `~/lib` is usually a symlink there)

## Install

The canonical copy of this project lives under **`$HOME/software/quit`**. Put the driver on your `PATH` with a symlink:

```bash
ln -sf "${HOME}/software/quit/quit" "${HOME}/bin/quit"
chmod +x "${HOME}/software/quit/quit"
```

## Usage

```text
quit <target> [<target>...]
quit -h
```

Examples:

```bash
quit Safari
quit safari          # case-insensitive — same as above
quit node
quit Safari Slack "/Applications/Discord.app"
```

Exit status is **0** only if every target is gone after escalation; otherwise **1**.

## How classification works

For each target, in order:

1. **Bundle directory** — If the path exists and is a directory whose name ends in `.app`, it is treated as an application (AppleScript name = basename without `.app`).
2. **Regular executable file** — If the path exists, is a normal file, is executable, and is not an `.app` folder, it is treated as a process (`killall` uses the basename, e.g. `/opt/homebrew/bin/node` → `node`).
3. **Known install locations** — If `<name>.app` exists (case-insensitive) under `/Applications`, `~/Applications`, `/System/Applications`, or `/Applications/Utilities` — including up to three levels deep (e.g. `/Applications/Setapp/Bartender.app`) — the target is treated as that application (so `quit safari` or `quit bartender` works without typing `.app` or matching case). Bundles nested inside other `.app` packages are ignored. The correct application name is resolved from the filesystem.
4. **Running process from a standard bundle** — If a process with that name (`pgrep -ix`, case-insensitive) is running and `lsof` shows a binary under `…/Something.app/Contents/MacOS/…`, and walking up finds a bundle in one of the locations above, the target is treated as that application.
5. **Otherwise** — Treated as a process name. If a matching process is running (`pgrep -ix`), the correct-case name is resolved from the process table; otherwise the input is used as-is.

Typical installs run apps from `/Applications`, not directly from Homebrew Cask staging dirs, so those paths are intentionally the focus.

## Escalation ladders

**Application**

1. AppleScript: `quit`
2. AppleScript: `quit saving no`
3. `killall` (SIGTERM)
4. `killall -9` (SIGKILL)

**Process**

1. `killall -INT` (SIGINT)
2. `killall` (SIGTERM)
3. `killall -9` (SIGKILL)

## Layout

| Path | Role |
|------|------|
| `quit` | Executable entry (symlink from `~/bin` recommended) |
| `lib/quit.sh` | Classification and escalation (sourced by `quit`) |
| `tests/` | Test suite (`bash tests/test-case-insensitive.sh`) |
| `$HOME/lib/common.sh` | Colors and log helpers ([`common-lib`](../common-lib/)) |

## License

Personal dotfiles / local utility; use and modify as you like.
