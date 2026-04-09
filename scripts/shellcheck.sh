#!/usr/bin/env bash
# Local lint: same checks as CI. Run from repo root: bash scripts/shellcheck.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
shellcheck -x quit lib/log.sh lib/quit.sh scripts/test-linux-docker.sh tests/run.sh
for f in tests/test-*.sh; do
  shellcheck -x "$f"
done
echo "shellcheck: OK"
