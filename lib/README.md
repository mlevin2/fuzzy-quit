# `quit/lib` — project-local library

This **`lib/`** belongs to the **`quit`** project only. It is **not** the same as **`~/lib`** (your home-wide `common.sh` symlink).

## Contents

| File | Role |
|------|------|
| `quit.sh` | Quit / escalation helpers for the `quit` command; expects **`common.sh`** logging (`info`, `warn`, …) to already be loaded. |

## How it is used

- The **`quit`** entrypoint (e.g. under **`~/bin`**) sources **`"${HOME}/lib/common.sh"`** first, then loads this project’s `quit.sh` by path relative to the `quit` install.
- Other scripts should **not** source `quit/lib/quit.sh` unless they are part of this project.

Home-wide layout ( **`~/lib`** vs **`~/bin/lib`** vs **`~/bin/bundled`** ): **`$HOME/docs/shared-shell-library.md`**.
