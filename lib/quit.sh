#!/usr/bin/env bash
#
# Copyright (c) 2026 Marshall Levin
# SPDX-License-Identifier: MIT
#
# Fuzzy Quit — graduated quit: macOS AppleScript + .app bundles + processes; other Unix: processes only.
# Source after lib/log.sh (info, warn, ok, err, die, hr, …).

quit_is_darwin() {
  [[ "$(uname -s 2>/dev/null)" == "Darwin" ]]
}

# Framed headers on stderr (uses hr, BOLD, DIM from lib/log.sh).
quit_tui_panel_begin() {
  local title="$1"
  echo >&2
  hr >&2
  printf >&2 '  %b%s%b\n' "$BOLD" "$title" "$NC"
  hr >&2
}

quit_tui_panel_hint() {
  printf >&2 '  %b%s%b\n' "$DIM" "$*" "$NC"
}

# Shared fzf styling (works with user FZF_DEFAULT_OPTS; these flags add structure).
quit_fzf_run() {
  fzf \
    --height 40% \
    --border rounded \
    --layout reverse \
    --pointer '▶' \
    --marker '✓ ' \
    "$@"
}

# Echo path to Name.app if it exists under common install locations.
quit_lookup_bundle_path() {
  quit_is_darwin || return 1
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
  quit_is_darwin || return 1
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
  quit_is_darwin || return 1
  local pid="$1" p
  while IFS= read -r p; do
    [[ "$p" == *'.app/Contents/MacOS/'* ]] && printf '%s' "$p" && return 0
  done < <(lsof -a -p "$pid" -d txt -Fn 2>/dev/null | sed -n 's/^n//p')
  return 1
}

# One application name per line: bundles under the same dirs as quit_lookup_bundle_path.
quit_enum_installed_app_names() {
  quit_is_darwin || return 0
  local d p
  for d in \
    "/Applications" \
    "${HOME}/Applications" \
    "/System/Applications" \
    "/Applications/Utilities"
  do
    [[ -d "$d" ]] || continue
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      basename "$p" .app
    done < <(find "$d" -maxdepth 3 -iname "*.app" -not -path "*/*.app/*" -print 2>/dev/null)
  done
}

# Running GUI app names (menu bar / Dock), one per line.
quit_osascript_running_app_names() {
  quit_is_darwin || return 0
  osascript 2>/dev/null <<'APPLESCRIPT' || true
tell application "System Events"
  set procNames to name of every application process
  set oldDelim to AppleScript's text item delimiters
  set AppleScript's text item delimiters to {linefeed}
  set outStr to procNames as string
  set AppleScript's text item delimiters to oldDelim
  return outStr
end tell
APPLESCRIPT
}

# Built once per shell (first substring / interactive use). Large; avoids re-scanning per target.
_quit_merged_app_list_built=""
_quit_merged_app_list_content=""
quit_merge_app_name_candidates() {
  if [[ -z "$_quit_merged_app_list_built" ]]; then
    _quit_merged_app_list_built=1
    _quit_merged_app_list_content=$(
      {
        quit_enum_installed_app_names
        if [[ "${QUIT_SKIP_SYSTEM_EVENTS:-}" != "1" ]]; then
          quit_osascript_running_app_names
        fi
      } | sort -u
    )
  fi
  printf '%s\n' "$_quit_merged_app_list_content"
}

# Lines of app names whose name contains $needle (case-insensitive, fixed-string).
quit_collect_substring_app_candidates() {
  local needle="$1"
  [[ -z "$needle" ]] && return 0
  # grep exits 1 when there are no matches; callers may use set -o pipefail.
  quit_merge_app_name_candidates | grep -Fi -- "$needle" | sort -u || true
}

# Unique running executable names (comm), one per line.
quit_enum_running_comm_names() {
  ps -ax -o comm= 2>/dev/null | sed 's/^[[:space:]]*//' | sort -u
}

quit_collect_substring_process_candidates() {
  local needle="$1"
  [[ -z "$needle" ]] && return 0
  quit_enum_running_comm_names | grep -Fi -- "$needle" | sort -u || true
}

# stdin: candidate lines (one per line). stdout: chosen line. fzf if available, else select.
quit_tui_pick_one() {
  local title="${1:-Choose one}"
  if command -v fzf >/dev/null 2>&1; then
    quit_tui_panel_begin "$title"
    quit_tui_panel_hint "Type to filter · Return confirms · Esc or Ctrl-C cancels"
    echo >&2
    quit_fzf_run --prompt="${title} › " || return 1
    return 0
  fi
  local -a opts=()
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    opts+=("$line")
  done
  [[ "${#opts[@]}" -eq 0 ]] && return 1
  quit_tui_panel_begin "$title"
  quit_tui_panel_hint "Enter the number of the row you want, then Return. Choose Cancel to abort."
  echo >&2
  local PS3 choice
  PS3="$(printf '%b#?%b ' "$LIGHT_BLUE" "$NC")"
  select choice in "${opts[@]}" "Cancel"; do
    [[ "$choice" == "Cancel" ]] && return 1
    [[ -n "$choice" ]] && printf '%s' "$choice" && return 0
  done < /dev/tty
}

# stdin: candidate lines. Resolves ambiguity; prints one chosen line to stdout.
quit_resolve_ambiguous_lines() {
  local title="$1"
  local body
  body=$(cat) || true
  [[ -z "${body//[$'\t\r\n']/}" ]] && return 1
  local -a lines=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    lines+=("$line")
  done <<< "$body"
  local n="${#lines[@]}"
  [[ "$n" -eq 1 ]] && { printf '%s' "${lines[0]}"; return 0; }
  [[ "$n" -eq 0 ]] && return 1
  printf '%s\n' "${lines[@]}" | quit_tui_pick_one "$title" || return 1
}

# Sorted unique lines for fzf multi-picker.
# Set QUIT_INTERACTIVE_INCLUDE_PS=0 to omit ps(1) comm names (quieter; apps only).
quit_interactive_candidate_list() {
  {
    quit_merge_app_name_candidates
    if [[ "${QUIT_INTERACTIVE_INCLUDE_PS:-1}" != "0" ]]; then
      quit_enum_running_comm_names
    fi
  } | awk 'NF { print }' | sort -u
}

# Interactive multi-select via fzf. Prints one target per line; returns 1 if cancelled / empty.
quit_interactive_fzf_pick() {
  local choices picked
  command -v fzf >/dev/null 2>&1 || return 1
  choices=$(quit_interactive_candidate_list) || true
  [[ -z "${choices//[$'\t\r\n']/}" ]] && return 1
  quit_tui_panel_begin "quit — choose targets"
  quit_tui_panel_hint "Tab toggles each row · Return quits every marked row"
  echo >&2
  picked=$(printf '%s\n' "$choices" | quit_fzf_run \
    --multi \
    --header 'Multi-select with Tab · Return to quit' \
    --header-first \
    --prompt='Quit › ') || return 1
  [[ -z "${picked//[$'\t\r\n']/}" ]] && return 1
  printf '%s\n' "$picked"
  return 0
}

# When fzf is unavailable: read targets from the terminal (one per line, blank line to finish).
quit_interactive_tty_targets() {
  quit_tui_panel_begin "quit — manual targets"
  warn "fzf is not on PATH — install for fuzzy search and multi-select (e.g. brew install fzf)."
  quit_tui_panel_hint "Enter one target per line (app name, path, or process name)."
  quit_tui_panel_hint "Empty line runs quit on everything you typed above. Ctrl-C cancels."
  echo >&2
  local line acc prompt
  prompt="$(printf '%bquit›%b ' "$LIGHT_BLUE" "$NC")"
  acc=
  while true; do
    IFS= read -r -p "$prompt" line < /dev/tty || return 1
    [[ -z "$line" ]] && break
    acc+="$line"$'\n'
  done
  [[ -z "${acc//[$'\t\r\n']/}" ]] && return 1
  printf '%s' "$acc"
  return 0
}

# Classify one user argument. Sets QUIT_KIND=app|process and QUIT_APP_NAME or QUIT_PROC_NAME
# for the caller.
# shellcheck disable=SC2034
quit_resolve_target() {
  local arg="$1"
  arg="${arg%/}"
  local base name bundle_path pid binary_path
  local sub_apps sub_procs chosen

  QUIT_KIND=
  QUIT_APP_NAME=
  QUIT_PROC_NAME=

  base="$(basename "$arg")"

  # Existing bundle directory (macOS .app); elsewhere treat like a named process for killall.
  if [[ -d "$arg" ]] && [[ "$base" == *.app ]]; then
    if quit_is_darwin; then
      QUIT_KIND=app
      QUIT_APP_NAME="${base%.app}"
    else
      QUIT_KIND=process
      QUIT_PROC_NAME="${base%.app}"
    fi
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

  # Exact process name running: prefer this over fuzzy app matching (e.g. quit node → CLI, not an app
  # whose display name happens to contain "node").
  if pid=$(pgrep -ix "$name" 2>/dev/null | head -1) && [[ -n "$pid" ]]; then
    if quit_is_darwin; then
      if binary_path=$(quit_lsof_app_binary "$pid") && [[ -n "$binary_path" ]]; then
        if bundle_path=$(quit_first_standard_bundle_walking_up "$binary_path") && [[ -n "$bundle_path" ]]; then
          QUIT_KIND=app
          QUIT_APP_NAME="$(basename "$bundle_path" .app)"
          return 0
        fi
      fi
    fi
    QUIT_KIND=process
    QUIT_PROC_NAME=$(ps -p "$pid" -o comm= 2>/dev/null | xargs basename 2>/dev/null) || QUIT_PROC_NAME="$name"
    return 0
  fi

  # Unambiguous case-insensitive substring against installed + running app names (macOS only)
  if quit_is_darwin && [[ "$arg" != */* ]] && [[ -n "$name" ]]; then
    sub_apps=$(quit_collect_substring_app_candidates "$name")
    if [[ -n "$sub_apps" ]]; then
      if chosen=$(printf '%s\n' "$sub_apps" | quit_resolve_ambiguous_lines "Applications matching \"$name\""); then
        QUIT_KIND=app
        QUIT_APP_NAME="${chosen//$'\r'/}"
        QUIT_APP_NAME="${QUIT_APP_NAME//$'\n'/}"
        return 0
      fi
      return 1
    fi
  fi

  # Unambiguous substring among running process comm names
  if [[ "$arg" != */* ]] && [[ -n "$name" ]]; then
    sub_procs=$(quit_collect_substring_process_candidates "$name")
    if [[ -n "$sub_procs" ]]; then
      if chosen=$(printf '%s\n' "$sub_procs" | quit_resolve_ambiguous_lines "Processes matching \"$name\""); then
        QUIT_KIND=process
        QUIT_PROC_NAME="${chosen//$'\r'/}"
        QUIT_PROC_NAME="${QUIT_PROC_NAME//$'\n'/}"
        return 0
      fi
      return 1
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

# Optional confirmation before SIGKILL (QUIT_CONFIRM_SIGKILL=1). Returns 1 to abort that step.
quit_maybe_confirm_sigkill() {
  local n="$1"
  [[ "${QUIT_DRY_RUN:-0}" == "1" ]] && return 0
  [[ "${QUIT_CONFIRM_SIGKILL:-0}" != "1" ]] && return 0
  local ans
  if ! read -r -p "Send SIGKILL to \"$n\"? [y/N] " ans < /dev/tty 2>/dev/null; then
    err "Cannot read confirmation; aborting before SIGKILL."
    return 1
  fi
  if [[ "$ans" != [yY] && "$ans" != [yY][eE][sS] ]]; then
    warn "Skipping SIGKILL for \"$n\"."
    return 1
  fi
  return 0
}

# True if a GUI app or process named like the bundle appears to be running.
quit_running_p() {
  local n="$1"
  pgrep -ix "$n" &>/dev/null && return 0
  quit_is_darwin || return 1
  pgrep -if "/${n}.app/Contents/MacOS/" &>/dev/null && return 0
  return 1
}

# Graduated quit for .app-style applications: AppleScript → SIGTERM → SIGKILL.
# Argument is the application name as shown in the menu bar (no ".app" suffix).
quit_app_graduated() {
  local app="${1%.app}"
  [[ -z "$app" ]] && die "quit: application name required"

  if [[ "${QUIT_DRY_RUN:-0}" == "1" ]]; then
    if quit_is_darwin; then
      info "[dry-run] Application \"$app\" — would run: AppleScript quit → AppleScript quit saving no → killall (SIGTERM) → killall -9 (SIGKILL)"
    else
      info "[dry-run] Application \"$app\" (non-macOS) — would run: killall -INT → killall (SIGTERM) → killall -9 (SIGKILL)"
    fi
    return 0
  fi

  if ! quit_is_darwin; then
    warn "Not on macOS — skipping AppleScript; using process signal ladder only."
    quit_process_graduated "$app"
    return $?
  fi

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
  quit_maybe_confirm_sigkill "$app" || return 1
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

  if [[ "${QUIT_DRY_RUN:-0}" == "1" ]]; then
    info "[dry-run] Process \"$name\" — would run: killall -INT → killall (SIGTERM) → killall -9 (SIGKILL)"
    return 0
  fi

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
  quit_maybe_confirm_sigkill "$name" || return 1
  killall -9 "$name" &>/dev/null || true
  sleep 1
  if ! pgrep -ix "$name" &>/dev/null; then
    ok "\"$name\" is no longer running."
    return 0
  fi

  err "Could not terminate \"$name\"."
  return 1
}
