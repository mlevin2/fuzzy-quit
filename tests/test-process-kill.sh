#!/usr/bin/env bash
# End-to-end process termination via quit_process_graduated.
# Run: bash tests/test-process-kill.sh
#
# 1) sleep(1) with a unique argv0 (exec -a) — normally dies on SIGINT (first ladder rung).
# 2) bash ignoring INT/TERM under a unique argv0 — ladder must reach SIGKILL.
#
# Uses exec -a instead of copying /bin/sleep into /tmp; on macOS, running a copied
# system binary from a writable temp path can be killed by platform policy (SIGKILL).
#
# Requires macOS or similar (bash, sleep, killall, pgrep), lib/log.sh, and lib/quit.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/log.sh"
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/quit.sh"

passed=0
failed=0

pass() {
  ok "  ✔ $*"
  ((++passed)) || true
}

fail() {
  err "  ✖ $*"
  ((++failed)) || true
}

sleep_cmd="$(command -v sleep)" || {
  err "sleep(1) not found"
  exit 1
}
bash_cmd="$(command -v bash)" || {
  err "bash not found"
  exit 1
}

# ── 1) Unique argv0 + sleep (SIGINT usually wins) ─────────────────────────

section "quit_process_graduated — unique argv0 + sleep"

name_sleep="quit_test_sp_${RANDOM}_$$"
child_sleep=

cleanup_sleep() {
  if [[ -n "${child_sleep:-}" ]] && kill -0 "$child_sleep" 2>/dev/null; then
    kill -9 "$child_sleep" 2>/dev/null || true
    wait "$child_sleep" 2>/dev/null || true
  fi
}
trap cleanup_sleep EXIT

"$bash_cmd" -c "exec -a \"$name_sleep\" \"$sleep_cmd\" 600" &
child_sleep=$!

for _ in $(seq 1 50); do
  if kill -0 "$child_sleep" 2>/dev/null && pgrep -ix "$name_sleep" &>/dev/null; then
    break
  fi
  sleep 0.05
done
if ! kill -0 "$child_sleep" 2>/dev/null; then
  fail "sleep child died before test (pid $child_sleep)"
elif ! pgrep -ix "$name_sleep" &>/dev/null; then
  fail "pgrep -ix \"$name_sleep\" does not match this OS (comm=$(ps -p "$child_sleep" -o comm= 2>/dev/null | tr -d '[:space:]' || echo '?'))"
elif quit_process_graduated "$name_sleep"; then
  sleep 0.4
  if kill -0 "$child_sleep" 2>/dev/null; then
    fail "sleep child pid still alive after graduation"
  elif pgrep -ix "$name_sleep" &>/dev/null; then
    fail "pgrep still lists \"$name_sleep\" after graduation"
  else
    pass "sleep with argv0 \"$name_sleep\" terminated"
  fi
else
  fail "quit_process_graduated returned non-zero for sleep"
fi

cleanup_sleep
trap - EXIT
child_sleep=

# ── 2) bash ignores INT/TERM under unique argv0 (SIGKILL required) ────────

section "quit_process_graduated — trap INT/TERM (expects SIGKILL)"

name_trap="quit_test_tp_${RANDOM}_$$"
child_trap=

cleanup_trap() {
  if [[ -n "${child_trap:-}" ]] && kill -0 "$child_trap" 2>/dev/null; then
    kill -9 "$child_trap" 2>/dev/null || true
    wait "$child_trap" 2>/dev/null || true
  fi
}
trap cleanup_trap EXIT

# Outer bash -c: replace with bash that traps then loops (trap survives; no exec to sleep).
"$bash_cmd" -c "exec -a \"$name_trap\" \"$bash_cmd\" -c 'trap \"\" 2 15; while sleep 1; do :; done'" &
child_trap=$!

for _ in $(seq 1 50); do
  if kill -0 "$child_trap" 2>/dev/null && pgrep -ix "$name_trap" &>/dev/null; then
    break
  fi
  sleep 0.05
done
if ! kill -0 "$child_trap" 2>/dev/null; then
  fail "trap child died before test (pid $child_trap)"
elif ! pgrep -ix "$name_trap" &>/dev/null; then
  fail "pgrep -ix \"$name_trap\" mismatch (comm=$(ps -p "$child_trap" -o comm= 2>/dev/null | tr -d '[:space:]' || echo '?'))"
elif quit_process_graduated "$name_trap"; then
  sleep 0.5
  if kill -0 "$child_trap" 2>/dev/null; then
    fail "trap child pid still alive after graduation"
  elif pgrep -ix "$name_trap" &>/dev/null; then
    fail "pgrep still lists \"$name_trap\" after graduation"
  else
    pass "trapped bash argv0 \"$name_trap\" killed (SIGKILL rung)"
  fi
else
  fail "quit_process_graduated returned non-zero for trapped bash"
fi

cleanup_trap
trap - EXIT
child_trap=

summary_bar "$passed" "$failed"
[[ "$failed" -eq 0 ]]
