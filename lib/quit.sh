#!/usr/bin/env bash
# Quit escalation for macOS — source after "${HOME}/lib/common.sh" (uses info, warn, ok, err, die).

# Echo path to Name.app if it exists under common install locations.
quit_lookup_bundle_path() {
  local name="${1%.app}"
  [[ -z "$name" ]] && return 1
  local d result
  for d in \
    "/Applications" \
    "${HOME}/Applications" \
    "/System/Applications" \
    "/Applications/Utilities"
  do
    # -maxdepth 3 to find apps in subdirectories (e.g. /Applications/Setapp/…)
    # -not -path to skip bundles nested inside another .app
    result=$(find "$d" -maxdepth 3 -iname "${name}.app" -not -path "*/*.app/*" -print -quit 2>/dev/null)
    if [[ -n "$result" ]]; then
      printf '%s' "$result"
      return 0
    fi
  done
  return 1
}

quit_is_standard_site_bundle() {
  local bundle="$1"
  [[ -d "$bundle/Contents/MacOS" ]] || return 1
  case "$bundle" in
    /Applications/Utilities/*.app) return 0 ;;
    /Applications/*.app) return 0 ;;
    "${HOME}/Applications"/*.app) return 0 ;;
    /System/Applications/*.app) return 0 ;;
    *) return 1 ;;
  esac
}

# From a binary inside a bundle, walk up and return the first *.app that lives in a standard site.
quit_first_standard_bundle_walking_up() {
  local f
  f=$(dirname "$1")
  while [[ "$f" != "/" ]]; do
    if [[ "$(basename "$f")" == *.app ]] && quit_is_standard_site_bundle "$f"; then
      printf '%s' "$f"
      return 0
    fi
    f=$(dirname "$f")
  done
  return 1
}

# First text mapping for this pid whose path looks like .../Something.app/Contents/MacOS/...
quit_lsof_app_binary() {
  local pid="$1" p
  while IFS= read -r p; do
    [[ "$p" == *'.app/Contents/MacOS/'* ]] && printf '%s' "$p" && return 0
  done < <(lsof -a -p "$pid" -d txt -Fn 2>/dev/null | sed -n 's/^n//p')
  return 1
}

# Classify one user argument. Sets QUIT_KIND=app|process and QUIT_APP_NAME or QUIT_PROC_NAME
# for the caller.
# shellcheck disable=SC2034
quit_resolve_target() {
  local arg="$1"
  arg="${arg%/}"
  local base name bundle_path pid binary_path

  QUIT_KIND=
  QUIT_APP_NAME=
  QUIT_PROC_NAME=

  base="$(basename "$arg")"

  # Existing bundle directory
  if [[ -d "$arg" ]] && [[ "$base" == *.app ]]; then
    QUIT_KIND=app
    QUIT_APP_NAME="${base%.app}"
    return 0
  fi

  # Existing executable file (not an .app folder): always treat as a plain process
  if [[ -f "$arg" ]] && [[ -x "$arg" ]] && [[ "$base" != *.app ]]; then
    QUIT_KIND=process
    QUIT_PROC_NAME="$base"
    return 0
  fi

  if [[ "$arg" != */* ]]; then
    name="${arg%.app}"
  else
    name="${base%.app}"
  fi

  if bundle_path=$(quit_lookup_bundle_path "$name") && [[ -n "$bundle_path" ]]; then
    QUIT_KIND=app
    QUIT_APP_NAME="$(basename "$bundle_path" .app)"
    return 0
  fi

  if pid=$(pgrep -ix "$name" 2>/dev/null | head -1) && [[ -n "$pid" ]]; then
    if binary_path=$(quit_lsof_app_binary "$pid") && [[ -n "$binary_path" ]]; then
      if bundle_path=$(quit_first_standard_bundle_walking_up "$binary_path") && [[ -n "$bundle_path" ]]; then
        QUIT_KIND=app
        QUIT_APP_NAME="$(basename "$bundle_path" .app)"
        return 0
      fi
    fi
  fi

  QUIT_KIND=process
  # Resolve correct case from a running process if possible
  local _pid
  if _pid=$(pgrep -ix "$name" 2>/dev/null | head -1) && [[ -n "$_pid" ]]; then
    QUIT_PROC_NAME=$(ps -p "$_pid" -o comm= 2>/dev/null | xargs basename 2>/dev/null) || QUIT_PROC_NAME="$name"
  else
    QUIT_PROC_NAME="$name"
  fi
  return 0
}

# True if a GUI app or process named like the bundle appears to be running.
quit_running_p() {
  local n="$1"
  pgrep -ix "$n" &>/dev/null && return 0
  pgrep -if "/${n}.app/Contents/MacOS/" &>/dev/null && return 0
  return 1
}

# Graduated quit for .app-style applications: AppleScript → SIGTERM → SIGKILL.
# Argument is the application name as shown in the menu bar (no ".app" suffix).
quit_app_graduated() {
  local app="${1%.app}"
  [[ -z "$app" ]] && die "quit: application name required"

  if ! quit_running_p "$app"; then
    warn "No matching process for \"$app\"; still trying AppleScript in case it is running."
  fi

  info "1/4 AppleScript: quit…"
  osascript -e "tell application \"${app//\"/\\\"}\" to quit" &>/dev/null || true
  sleep 2
  if ! quit_running_p "$app"; then
    ok "\"$app\" is no longer running."
    return 0
  fi

  info "2/4 AppleScript: quit saving no…"
  osascript -e "tell application \"${app//\"/\\\"}\" to quit saving no" &>/dev/null || true
  sleep 2
  if ! quit_running_p "$app"; then
    ok "\"$app\" is no longer running."
    return 0
  fi

  info "3/4 killall (SIGTERM)…"
  killall "$app" &>/dev/null || true
  sleep 1
  if ! quit_running_p "$app"; then
    ok "\"$app\" is no longer running."
    return 0
  fi

  info "4/4 killall -9 (SIGKILL)…"
  killall -9 "$app" &>/dev/null || true
  sleep 1
  if ! quit_running_p "$app"; then
    ok "\"$app\" is no longer running."
    return 0
  fi

  err "Could not terminate \"$app\"."
  return 1
}

# Plain processes / CLI: SIGINT → SIGTERM → SIGKILL (no AppleScript).
# Name is the executable as matched by killall / pgrep -x (e.g. node, or basename of a path).
quit_process_graduated() {
  local name="$1"
  [[ -z "$name" ]] && die "quit: process name required"

  if ! pgrep -ix "$name" &>/dev/null; then
    warn "No process with exact name \"$name\" (pgrep -ix)."
  fi

  info "1/3 killall -INT (SIGINT)…"
  killall -INT "$name" &>/dev/null || true
  sleep 1
  if ! pgrep -ix "$name" &>/dev/null; then
    ok "\"$name\" is no longer running."
    return 0
  fi

  info "2/3 killall (SIGTERM)…"
  killall "$name" &>/dev/null || true
  sleep 1
  if ! pgrep -ix "$name" &>/dev/null; then
    ok "\"$name\" is no longer running."
    return 0
  fi

  info "3/3 killall -9 (SIGKILL)…"
  killall -9 "$name" &>/dev/null || true
  sleep 1
  if ! pgrep -ix "$name" &>/dev/null; then
    ok "\"$name\" is no longer running."
    return 0
  fi

  err "Could not terminate \"$name\"."
  return 1
}
