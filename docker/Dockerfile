# Linux test image — same toolchain as .github/workflows/ci-linux.yml (Ubuntu + shellcheck + psmisc + procps).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        shellcheck \
        psmisc \
        procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Override via docker compose `command` or `docker run … bash …`.
CMD ["bash", "-c", "set -euo pipefail && bash scripts/shellcheck.sh && bash tests/run.sh"]
