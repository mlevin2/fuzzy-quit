# Fuzzy Quit

**Fuzzy Quit** (`fuzzy-quit`) is a small Bash tool that stops running software using **graduated escalation** (polite quit → stronger signals). It accepts **exact names**, **paths**, and **unambiguous fuzzy substrings** (with interactive disambiguation when needed).

**macOS and Linux:** Install and use the **same** `quit` command on **both** platforms. **Linux** (and other non-macOS Unix) focuses on **command-line processes** with the full **SIGINT → SIGTERM → SIGKILL** ladder. **macOS** adds **extra** capabilities on top of that: **`.app` GUI applications**, **AppleScript** / System Events where available, and richer matching against installed apps—details are in **Requirements** below.

The command you run is still named **`quit`** on your `PATH`; the repository and package name are **`fuzzy-quit`** so the project is easy to find on GitHub.

[![CI macOS](https://github.com/mlevin2/fuzzy-quit/actions/workflows/ci-macos.yml/badge.svg)](https://github.com/mlevin2/fuzzy-quit/actions/workflows/ci-macos.yml)
[![CI Linux](https://github.com/mlevin2/fuzzy-quit/actions/workflows/ci-linux.yml/badge.svg)](https://github.com/mlevin2/fuzzy-quit/actions/workflows/ci-linux.yml)

- **Upstream:** [github.com/mlevin2/fuzzy-quit](https://github.com/mlevin2/fuzzy-quit)
- **License:** [MIT](LICENSE) — see `LICENSE` in the repository root.
- **Contributing:** see [CONTRIBUTING.md](CONTRIBUTING.md).

**GitHub topics** (for discoverability — GitHub allows **20** topics per repo; upstream is set with `gh repo edit --add-topic …`):  
`macos` · `bash` · `shell-script` · `zsh` · `fzf` · `killall` · `pgrep` · `process-management` · `cli` · `automation` · `applescript` · `macos-apps` · `linux` · `signals` · `sigterm` · `sigkill` · `productivity` · `dotfiles` · `substring-matching` · `fuzzy-matching`  
*(Use **Search keywords** below for extra terms like “terminal” that do not fit the topic cap.)*

**Search keywords:** quit applications, kill processes, graduated kill, macOS quit app, AppleScript quit, `killall` wrapper, process picker, fuzzy process name, interactive quit, `fzf` process selection.

## Requirements

- **macOS** — full behavior: `.app` bundles, **AppleScript**, System Events (optional), substring app matching, and process escalation.
- **Linux** (and other non-macOS Unix): **processes only** — same **SIGINT → SIGTERM → SIGKILL** ladder via `killall` / `pgrep`. No `osascript`, no `.app` integration, no installed-GUI substring catalog (interactive list is mostly **`ps`** names). A target that would be an “application” on macOS is handled with the **process** ladder after a short warning.
- **Bash**
- **`killall`** and **`pgrep`** on `PATH` (on Debian/Ubuntu, `psmisc` / `procps` packages)
- Optional: [fzf](https://github.com/junegunn/fzf) for interactive picking and fuzzy search

All logging and TUI helpers are **vendored** in `lib/log.sh` (no external dotfiles library).

## Install

Clone the repository (forks: swap the owner in the URL):

```bash
git clone https://github.com/mlevin2/fuzzy-quit.git
cd fuzzy-quit
chmod +x quit
```

Put **`quit`** on your `PATH`. A **symlink** is recommended and is fully supported:

```bash
ln -sf "$(pwd)/quit" "$HOME/bin/quit"   # or any directory on your PATH
```

The driver resolves **`FUZZY_QUIT_ROOT`** by following symlinks from the path you executed (e.g. `~/bin/quit` → …/fuzzy-quit/quit), so `lib/*.sh` and **`VERSION`** always load from the real checkout.

Confirm:

```bash
quit --version
quit --help
```

## Usage (summary)

```text
quit [<options>] [<target>...]
quit [<options>] [--no-ps]
quit [<options>] --pick | -p [--no-ps]
```

| Option | Meaning |
|--------|---------|
| `-h`, `--help` | Usage (exits before processing targets if present). |
| `--version` | Print version from `VERSION`. |
| `-n`, `--dry-run` | Show how each target would be quit; **no** `osascript` or `killall`. |
| `--confirm-sigkill` | Prompt before the final **`killall -9`** step. |
| `--no-ps` | Interactive mode: candidate list is **apps only** (no `ps` `comm` names). |

With **no arguments**, or only **`--pick`** / **`-p`**, **`quit`** opens **fzf** (multi-select with Tab) when available; otherwise it prompts for **one target per line** until a blank line.

**Examples:**

```bash
quit Safari node "/Applications/Slack.app"
quit --dry-run outlook
quit --confirm-sigkill SomeApp
quit --no-ps
```

Exit status is **0** only if every target is handled successfully; otherwise **1**.

## How classification works

**Platform:** `uname -s` must be **`Darwin`** for any macOS-only step below (bundle catalog, `lsof` `.app` detection, AppleScript, System Events, substring **app** matching).

For each target, in order:

1. **Bundle directory** — Existing directory whose name ends in `.app`. On **macOS** → **application**; elsewhere → **process** (basename without `.app`) for the signal ladder only.
2. **Regular executable file** — Existing non-`.app` executable; **process** (basename).
3. **Known install locations** — **macOS only:** `<name>.app` under `/Applications`, `~/Applications`, `/System/Applications`, `/Applications/Utilities` (up to three levels deep).
4. **Exact running process name** — `pgrep -ix`. **macOS:** if `lsof` shows a binary under a standard `.app` → **application**; else **process**. **Non-macOS:** always **process** once `pgrep` matches (no `.app` walk).
5. **Substring on app names** — **macOS only** (installed + running GUI names). Same disambiguation rules as before.
6. **Substring on `ps` `comm` names** — Any supported OS.
7. **Otherwise** — **Process** name for `killall` (case from `pgrep` when possible).

**Path-shaped arguments** (containing `/`) **skip** substring steps; only the **basename** is used for the steps above.

On **macOS**, the first substring or interactive use in one run **caches** installed (and optionally GUI) app names.

## Environment variables

| Variable | Meaning |
|----------|---------|
| `QUIT_INTERACTIVE_INCLUDE_PS` | `0` (also set by `--no-ps`) omits `ps` names from the interactive list. |
| `QUIT_SKIP_SYSTEM_EVENTS` | `1` skips AppleScript / System Events for **running GUI** names (tests, headless). |
| `QUIT_DRY_RUN` | `1` — same idea as `--dry-run` (usually set by the driver). |
| `QUIT_CONFIRM_SIGKILL` | `1` — same idea as `--confirm-sigkill`. |

## Ambiguous matches

If several apps or processes match a substring, **`quit`** does not guess: **fzf** or **`select`** on `/dev/tty`.

## Escalation ladders

**Application (macOS only):** AppleScript `quit` → AppleScript `quit saving no` → `killall` (SIGTERM) → `killall -9`.  
**Application resolved on non-macOS:** same as **process** (warning printed; no AppleScript).

**Process:** `killall -INT` → `killall` (SIGTERM) → `killall -9`.

## Example inputs and behavior

Below, “**app ladder**” and “**process ladder**” refer to those sequences. Each argument is classified independently.

### Entry mode

| Input | Behavior |
|-------|----------|
| `quit -h` / `quit --help` | Prints usage; exits **0**. |
| `quit` | Interactive picker (fzf or tty). |
| `quit --pick` / `-p` | Same. |
| `quit --no-ps` | Interactive list without `ps` names (fzf only; ignored with tty fallback). |
| `quit Safari --no-ps` | **Not** interactive: `--no-ps` stripped; only **`Safari`** is processed. |
| `quit a b c` | Three targets, independently. |
| `quit --version` | Prints `VERSION` and exits. |

### Per-target examples

| Example | Typical behavior |
|---------|------------------|
| `quit "/Applications/Safari.app"` | **App** → app ladder. |
| `quit "/opt/homebrew/bin/node"` | **Process** `node` → process ladder. |
| `quit Safari` | **App** if bundle found → app ladder. |
| `quit node` (CLI running) | **Process** `node` → process ladder (substring apps skipped). |
| `quit outlook` | Substring → one app (e.g. Microsoft Outlook) → app ladder. |
| `quit microsoft` (ambiguous) | Picker → one app → app ladder. |
| `quit nosuchthing_xyz` | **Process** name as given → process ladder (may warn if nothing runs). |
| `quit Foo/Bar` | Basename **`Bar`**; **no** substring steps. |

### TUI

Pickers use framed headers (`hr`, bold titles, dim hints). **fzf** uses rounded borders and markers. Normal operation logs with colored **`info` / `warn` / `ok` / `err`**.

### Limits (by design)

- **First match** for some exact bundle lookups (`find` `-quit`); no prompt for duplicate exact names.
- Apps **only** outside scanned trees and **not** running may need a **full `.app` path**.
- **`QUIT_SKIP_SYSTEM_EVENTS=1`** drops running GUI names from the substring merge.

## Running the tests

From the repository root (**full suite on macOS**; **Linux** runs all tests except `test-case-insensitive.sh`):

```bash
bash tests/run.sh
```

Lint (requires **shellcheck**):

```bash
bash scripts/shellcheck.sh
```

`tests/test-case-insensitive.sh` sets **`QUIT_SKIP_SYSTEM_EVENTS=1`** and runs **only on macOS**. On Linux, **`tests/run.sh`** skips it automatically. The runner discovers every **`tests/test-*.sh`** file.

## Manual smoke checklist (before a release)

Run once on a real Mac with your usual shell:

1. `quit --version` and `quit --help`
2. `quit --dry-run Safari` (or another installed app) — no processes quit
3. Quit a **real** test app you can afford to close
4. A **CLI** tool you can restart (e.g. `quit --dry-run` then real `quit` on it)
5. Optional: ambiguous substring → picker → choose one
6. Optional: bare `quit` with **fzf** — multi-select
7. Optional: `quit --confirm-sigkill` on a disposable process and decline **y** at the SIGKILL prompt

## Security note

This tool runs **`osascript`**, **`killall`**, and **`pgrep`**. It is aimed at **local interactive** use. Review targets (especially after substring resolution) before confirming **SIGKILL**.

## Layout

| Path | Role |
|------|------|
| `quit` | Entry script (install on `PATH` as `quit`) |
| `VERSION` | Release version string for `--version` |
| `LICENSE` | MIT |
| `lib/log.sh` | Colors, `info`/`warn`/…, `section`, `summary_bar` |
| `lib/quit.sh` | Classification and escalation |
| `tests/run.sh` | Runs all `tests/test-*.sh` |
| `scripts/shellcheck.sh` | Local shellcheck driver |
| `.github/workflows/ci-macos.yml` | **macOS** CI (shellcheck + full tests) |
| `.github/workflows/ci-linux.yml` | **Linux** CI (shellcheck + tests; skips macOS-only file) |

## Release checklist (maintainers)

1. Bump **`VERSION`** and tag (`v0.1.0`).
2. Run **`bash scripts/shellcheck.sh`** and **`bash tests/run.sh`** on macOS.
3. Run the **manual smoke** list above.
4. Ensure **`LICENSE`** copyright year / holder is correct for your legal needs (see note below).

**Copyright:** `LICENSE` lists **Marshall Levin** (2026). Adjust if your situation requires a different legal notice.
