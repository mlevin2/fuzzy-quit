#!/usr/bin/env bash
# Run Linux CI parity (shellcheck + tests) inside Docker — same image as docker-compose.yml.
#
# Usage (from anywhere):
#   bash /path/to/fuzzy-quit/scripts/test-linux-docker.sh
# Or from repo root:
#   bash scripts/test-linux-docker.sh
#   bash scripts/test-linux-docker.sh bash tests/run.sh          # tests only
#   bash scripts/test-linux-docker.sh bash scripts/shellcheck.sh # lint only
#
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
exec docker compose run --rm test-linux "$@"
