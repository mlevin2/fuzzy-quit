#!/usr/bin/env bash
# Extra resolution and dry-run checks.
# Run: bash tests/test-resolve-edge.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/log.sh"
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/quit.sh"

export QUIT_SKIP_SYSTEM_EVENTS=1

passed=0
failed=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    ok "  ✔ $label"
    ((++passed)) || true
  else
    err "  ✖ $label"
    err "    expected: '$expected'"
    err "    actual:   '$actual'"
    ((++failed)) || true
  fi
}

section "quit_resolve_target — slash in argument skips substring"

quit_resolve_target "Zzz_NoSuchDir_Xxx/WeirdNameXyz"
assert_eq "kind" "process" "$QUIT_KIND"
assert_eq "proc basename" "WeirdNameXyz" "$QUIT_PROC_NAME"

section "quit_process_graduated — dry-run returns 0 without killall"

export QUIT_DRY_RUN=1
if quit_process_graduated "NonexistentProcessXyz999"; then
  ok "  ✔ dry-run process graduation exits 0"
  ((++passed)) || true
else
  err "  ✖ dry-run should succeed"
  ((++failed)) || true
fi
unset QUIT_DRY_RUN

section "quit_app_graduated — dry-run returns 0 without AppleScript"

export QUIT_DRY_RUN=1
if quit_app_graduated "NonexistentAppXyz999"; then
  ok "  ✔ dry-run app graduation exits 0"
  ((++passed)) || true
else
  err "  ✖ dry-run app should succeed"
  ((++failed)) || true
fi
unset QUIT_DRY_RUN

summary_bar "$passed" "$failed"
[[ "$failed" -eq 0 ]]
