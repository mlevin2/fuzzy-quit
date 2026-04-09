# Local Linux parity with .github/workflows/ci-linux.yml (Docker required).
.PHONY: test-linux test-linux-shellcheck test-linux-tests docker-build-linux

# Default: shellcheck + tests/run.sh (matches CI Linux test job after checkout).
test-linux:
	docker compose run --rm test-linux

test-linux-shellcheck:
	docker compose run --rm test-linux bash scripts/shellcheck.sh

test-linux-tests:
	docker compose run --rm test-linux bash tests/run.sh

docker-build-linux:
	docker compose build test-linux
