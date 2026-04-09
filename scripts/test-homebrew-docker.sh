#!/usr/bin/env bash
# Run a Homebrew install smoke test inside Docker (official Homebrew image).
# Does not install anything on the host; safe alongside a dev checkout on PATH.
#
# Usage: bash scripts/test-homebrew-docker.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"
exec docker compose -f docker-compose.brew.yml run --rm homebrew-smoke
