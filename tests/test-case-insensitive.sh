#!/usr/bin/env bash
# Tests for case-insensitive target resolution.
# Run: bash tests/test-case-insensitive.sh
# Requires macOS with /Applications/Safari.app present.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# Source dependencies
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/log.sh"
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/quit.sh"

# Avoid System Events / osascript in CI or headless runs (can block waiting for permissions).
export QUIT_SKIP_SYSTEM_EVENTS=1

passed=0
failed=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    ok "  ✔ $label"
    (( ++passed )) || true
  else
    err "  ✖ $label"
    err "    expected: '$expected'"
    err "    actual:   '$actual'"
    (( ++failed )) || true
  fi
}

# ── quit_lookup_bundle_path ──────────────────────────────────────────

section "quit_lookup_bundle_path — case-insensitive"

# Pick an app that definitely exists on every Mac
if [[ -d "/Applications/Safari.app" ]]; then
  APP_NAME="Safari"
  APP_PATH="/Applications/Safari.app"
elif [[ -d "/System/Applications/Calculator.app" ]]; then
  APP_NAME="Calculator"
  APP_PATH="/System/Applications/Calculator.app"
else
  die "No known app found to test against"
fi

for variant in "$APP_NAME" "$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')" \
               "$(echo "$APP_NAME" | tr '[:lower:]' '[:upper:]')"; do
  result=$(quit_lookup_bundle_path "$variant") || true
  assert_eq "lookup '$variant' finds bundle" "$APP_PATH" "$result"
done

# With .app suffix
lc_name="$(echo "$APP_NAME" | tr '[:upper:]' '[:lower:]')"
result=$(quit_lookup_bundle_path "${lc_name}.app") || true
assert_eq "lookup '${lc_name}.app' strips suffix and finds bundle" "$APP_PATH" "$result"

# Nonexistent app still fails
if quit_lookup_bundle_path "NoSuchAppXyz123" &>/dev/null; then
  err "  ✖ nonexistent app should return 1"
  (( ++failed )) || true
else
  ok "  ✔ nonexistent app returns 1"
  (( ++passed )) || true
fi

# ── quit_resolve_target — app classification ─────────────────────────

section "quit_resolve_target — app via bundle (case-insensitive)"

for variant in "$APP_NAME" "$lc_name" "$(echo "$APP_NAME" | tr '[:lower:]' '[:upper:]')"; do
  quit_resolve_target "$variant"
  assert_eq "resolve '$variant' → kind=app" "app" "$QUIT_KIND"
  assert_eq "resolve '$variant' → name=$APP_NAME" "$APP_NAME" "$QUIT_APP_NAME"
done

# ── quit_resolve_target — process fallback ───────────────────────────

section "quit_resolve_target — process fallback (case-insensitive)"

# Use a name that won't match any bundle
quit_resolve_target "nosuchprocess_xyz"
assert_eq "resolve unknown → kind=process" "process" "$QUIT_KIND"
assert_eq "resolve unknown → proc name kept" "nosuchprocess_xyz" "$QUIT_PROC_NAME"

# ── quit_running_p — case-insensitive process check ──────────────────

section "quit_running_p — case-insensitive"

# Finder is always running on macOS
for variant in "Finder" "FINDER" "finder"; do
  if quit_running_p "$variant"; then
    ok "  ✔ quit_running_p '$variant' finds Finder"
    (( ++passed )) || true
  else
    err "  ✖ quit_running_p '$variant' should find Finder"
    (( ++failed )) || true
  fi
done

# ── quit_resolve_target — substring bundle match ─────────────────────

section "quit_resolve_target — substring (installed app name)"

if [[ -d "/System/Applications/Calculator.app" ]]; then
  quit_resolve_target "calc"
  assert_eq "resolve 'calc' → kind=app (substring)" "app" "$QUIT_KIND"
  assert_eq "resolve 'calc' → Calculator" "Calculator" "$QUIT_APP_NAME"
else
  ok "  (skip) no /System/Applications/Calculator.app for substring test"
  (( ++passed )) || true
fi

# Nonexistent process
if quit_running_p "NoSuchProcessXyz123"; then
  err "  ✖ nonexistent process should return 1"
  (( ++failed )) || true
else
  ok "  ✔ nonexistent process returns 1"
  (( ++passed )) || true
fi

# ── Summary ──────────────────────────────────────────────────────────

summary_bar "$passed" "$failed"

[[ "$failed" -eq 0 ]]
