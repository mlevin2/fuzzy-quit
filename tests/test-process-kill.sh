#!/usr/bin/env bash
# End-to-end process termination via quit_process_graduated.
# Run: bash tests/test-process-kill.sh
#
# 1) sleep(1) under a unique process name — normally dies on SIGINT (first ladder rung).
# 2) bash ignoring INT/TERM under a unique process name — ladder must reach SIGKILL.
#
# macOS: use exec -a so argv0 is unique. Copied system binaries under /tmp can be
# SIGKILL'd by platform policy, so we avoid cp(1) there.
#
# Linux: exec -a does not change /proc/PID/comm (still sleep/bash), so pgrep -ix and
# killall would not match. We copy sleep/bash into a short unique basename (≤15 chars
# for TASK_COMM_LEN) under a temp dir instead.
#
# Requires bash, sleep, killall, pgrep, cp, chmod, mktemp; lib/log.sh and lib/quit.sh.

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

# ── 1) Unique process name + sleep (SIGINT usually wins) ─────────────────

section "quit_process_graduated — unique process name + sleep"

name_sleep=
child_sleep=
sleep_tmp=""

cleanup_sleep() {
  if [[ -n "${child_sleep:-}" ]] && kill -0 "$child_sleep" 2>/dev/null; then
    kill -9 "$child_sleep" 2>/dev/null || true
    wait "$child_sleep" 2>/dev/null || true
  fi
  if [[ -n "${sleep_tmp:-}" ]]; then
    rm -rf "${sleep_tmp}"
    sleep_tmp=""
  fi
}
trap cleanup_sleep EXIT

if quit_is_darwin; then
  name_sleep="quit_test_sp_${RANDOM}_$$"
  "$bash_cmd" -c "exec -a \"$name_sleep\" \"$sleep_cmd\" 600" &
  child_sleep=$!
else
  sleep_tmp=$(mktemp -d)
  chmod 700 "$sleep_tmp"
  # Basename ≤15 chars so Linux comm and killall(1) match.
  sp="${sleep_tmp}/s${RANDOM}$$"
  cp "$sleep_cmd" "$sp"
  chmod +x "$sp"
  "$sp" 600 &
  child_sleep=$!
  name_sleep=$(basename "$sp")
fi
# Avoid bash job-control "Killed" noise when the child is SIGKILL'd during the ladder.
disown "$child_sleep" 2>/dev/null || true

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
    pass "sleep as \"$name_sleep\" terminated"
  fi
else
  fail "quit_process_graduated returned non-zero for sleep"
fi

cleanup_sleep
trap - EXIT
child_sleep=
sleep_tmp=

# ── 2) bash ignores INT/TERM under unique name (SIGKILL required) ─────────

section "quit_process_graduated — trap INT/TERM (expects SIGKILL)"

name_trap=
child_trap=
trap_tmp=""

cleanup_trap() {
  if [[ -n "${child_trap:-}" ]] && kill -0 "$child_trap" 2>/dev/null; then
    kill -9 "$child_trap" 2>/dev/null || true
    wait "$child_trap" 2>/dev/null || true
  fi
  if [[ -n "${trap_tmp:-}" ]]; then
    rm -rf "${trap_tmp}"
    trap_tmp=""
  fi
}
trap cleanup_trap EXIT

if quit_is_darwin; then
  name_trap="quit_test_tp_${RANDOM}_$$"
  "$bash_cmd" -c "exec -a \"$name_trap\" \"$bash_cmd\" -c 'trap \"\" 2 15; while sleep 1; do :; done'" &
  child_trap=$!
else
  trap_tmp=$(mktemp -d)
  chmod 700 "$trap_tmp"
  tp="${trap_tmp}/t${RANDOM}$$"
  cp "$bash_cmd" "$tp"
  chmod +x "$tp"
  "$tp" -c 'trap "" 2 15; while sleep 1; do :; done' &
  child_trap=$!
  name_trap=$(basename "$tp")
fi
disown "$child_trap" 2>/dev/null || true

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
    pass "trapped bash as \"$name_trap\" killed (SIGKILL rung)"
  fi
else
  fail "quit_process_graduated returned non-zero for trapped bash"
fi

cleanup_trap
trap - EXIT
child_trap=
trap_tmp=

summary_bar "$passed" "$failed"
[[ "$failed" -eq 0 ]]
