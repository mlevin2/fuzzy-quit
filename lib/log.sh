#!/usr/bin/env bash
#
# Copyright (c) 2026 Marshall Levin
# SPDX-License-Identifier: MIT
#
# Minimal logging and TUI helpers for Fuzzy Quit (no external dotfiles).

RED='\033[0;31m'
YELLOW='\033[0;49;33m'
GREEN='\033[0;32m'
LIGHT_BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info() { echo -e >&2 "${LIGHT_BLUE}$*${NC}"; }
warn() { echo -e >&2 "${YELLOW}$*${NC}"; }
ok() { echo -e >&2 "${GREEN}$*${NC}"; }
err() { echo -e >&2 "${RED}$*${NC}"; }
die() { err "$*"; exit 1; }

_term_width() { tput cols 2>/dev/null || echo 60; }

# shellcheck disable=SC2120
hr() {
  local char="${1:-─}" color="${2:-$DIM}"
  local width
  width=$(_term_width)
  printf >&2 '%b' "$color"
  printf >&2 '%*s' "$width" '' | tr ' ' "$char"
  printf >&2 '%b\n' "$NC"
}

section() {
  local title="$1"
  echo >&2
  hr
  printf >&2 '%b  %b%b\n' "$BOLD" "$title" "$NC"
  hr
}

_repeat() {
  local char="$1" count="$2"
  [[ $count -le 0 ]] && return
  printf '%*s' "$count" '' | tr ' ' "$char"
}

summary_bar() {
  local passed=$1
  local failed=$2
  local total=$((passed + failed))
  local width
  width=$(( $(_term_width) - 4 ))

  echo >&2
  if [[ $total -eq 0 ]]; then
    warn "  No steps were run."
  elif [[ $failed -eq 0 ]]; then
    printf >&2 '  %b%s%b\n' "$GREEN" "$(_repeat '█' "$width")" "$NC"
    printf >&2 '  %b✔ All %d steps passed%b\n' "$GREEN" "$total" "$NC"
  else
    local pwidth=$((width * passed / total))
    local fwidth=$((width - pwidth))
    printf >&2 '  %b%s%b%b%s%b\n' \
      "$GREEN" "$(_repeat '█' "$pwidth")" "$NC" \
      "$RED" "$(_repeat '█' "$fwidth")" "$NC"
    printf >&2 '  %b✔ %d passed%b  %b✖ %d failed%b\n' \
      "$GREEN" "$passed" "$NC" "$RED" "$failed" "$NC"
  fi
  echo >&2
}
