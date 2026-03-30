# quit

See **`$HOME/software/README.md`** for how this fits under `~/software` and how **`$HOME/lib`** stays the canonical path for shared shell code.

macOS helper to stop applications and command-line processes with **graduated escalation**. Each argument is classified independently as either a **GUI application** (`.app` bundle) or a **plain process**, then the appropriate ladder runs.

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
quit node
quit Safari Slack "/Applications/Discord.app"
```

Exit status is **0** only if every target is gone after escalation; otherwise **1**.

## How classification works

For each target, in order:

1. **Bundle directory** — If the path exists and is a directory whose name ends in `.app`, it is treated as an application (AppleScript name = basename without `.app`).
2. **Regular executable file** — If the path exists, is a normal file, is executable, and is not an `.app` folder, it is treated as a process (`killall` uses the basename, e.g. `/opt/homebrew/bin/node` → `node`).
3. **Known install locations** — If `<name>.app` exists under `/Applications`, `~/Applications`, `/System/Applications`, or `/Applications/Utilities`, the target is treated as that application (so `quit Safari` works without typing `.app`).
4. **Running process from a standard bundle** — If a process with that exact name (`pgrep -x`) is running and `lsof` shows a binary under `…/Something.app/Contents/MacOS/…`, and walking up finds a bundle in one of the locations above, the target is treated as that application.
5. **Otherwise** — Treated as a process name (`pgrep -x` / `killall`).

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
| `$HOME/lib/common.sh` | Colors and log helpers ([`common-lib`](../common-lib/)) |

## License

Personal dotfiles / local utility; use and modify as you like.
