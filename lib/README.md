# `lib/` — Fuzzy Quit libraries

Project-local Bash for the **`quit`** command. This is **not** a user-wide `~/lib`.

| File | Role |
|------|------|
| `log.sh` | Terminal colors and helpers: `info`, `warn`, `ok`, `err`, `die`, `hr`, `section`, `summary_bar` (MIT, vendored). |
| `quit.sh` | Target classification and graduated quit logic; source **`log.sh`** first. |

Optional environment variables are documented in the project **`README.md`**.
