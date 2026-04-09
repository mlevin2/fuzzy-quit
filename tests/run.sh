#!/usr/bin/env bash
# Run every tests/test-*.sh script and report a combined result.
# Usage (from anywhere):
#   bash /path/to/quit/tests/run.sh
# Or from the repo root:
#   bash tests/run.sh
#
# On non-macOS, test-case-insensitive.sh is skipped (requires macOS .app layout).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

pass_files=0
fail_files=0
found_files=0
executed_files=0

while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  ((++found_files)) || true
  bn="$(basename "$f")"

  if [[ "$(uname -s 2>/dev/null)" != "Darwin" ]] && [[ "$bn" == "test-case-insensitive.sh" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $bn (skipped on non-macOS)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    continue
  fi

  ((++executed_files)) || true
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $bn"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if bash "$f"; then
    ((++pass_files)) || true
  else
    ((++fail_files)) || true
  fi
done < <(find "$ROOT/tests" -maxdepth 1 -type f -name 'test-*.sh' | sort)

if [[ "$found_files" -eq 0 ]]; then
  echo "quit tests: no tests/test-*.sh files under $ROOT/tests" >&2
  exit 1
fi

if [[ "$executed_files" -eq 0 ]]; then
  echo "quit tests: all ${found_files} file(s) skipped on $(uname -s 2>/dev/null || echo unknown)."
  exit 0
fi

echo ""
if [[ "$fail_files" -eq 0 ]]; then
  echo "quit tests: all ${pass_files} executed file(s) passed (${found_files} total, $((found_files - executed_files)) skipped)."
  exit 0
fi

echo "quit tests: ${fail_files} file(s) failed, ${pass_files} file(s) passed." >&2
exit 1
