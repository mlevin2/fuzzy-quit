#!/usr/bin/env bash
# Commands shared by docker-compose.brew.yml, docker/Dockerfile.homebrew-smoke, and
# .github/workflows/brew-smoke.yml. Run inside the official Homebrew image or any
# environment where `brew` is available.
set -euo pipefail

brew tap mlevin2/tap
brew install fuzzy-quit
quit --version
quit --help >/dev/null
