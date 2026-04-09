# Contributing

Thanks for helping improve **Fuzzy Quit** (`fuzzy-quit`).

End-user install paths (Homebrew keg vs git) are documented in **[INSTALL.md](INSTALL.md)**. If install layout or dependencies change, update that file and the **[homebrew-tap](https://github.com/mlevin2/homebrew-tap)** formula when you cut a release.

## Development

- **Shell**: Bash 3.2+ (macOS `/bin/bash` is fine). Prefer POSIX-friendly patterns where practical.
- **Lint**: From the repository root run `bash scripts/shellcheck.sh` (requires [shellcheck](https://github.com/koalaman/shellcheck) on `PATH`).
- **Tests**: Run `bash tests/run.sh`. **macOS** runs the full suite; **Linux** skips `test-case-insensitive.sh` (bundle paths / Finder apps). CI runs both.
- **Linux in Docker** (same packages as CI): `bash scripts/test-linux-docker.sh` or `make test-linux` (see **README** → *Running the tests* → *Linux (Docker)*).

## Pull requests

1. Run **shellcheck** and the **full test suite** locally.
2. Describe the behavior change and any new flags or environment variables.
3. Update **README.md** if user-visible behavior changes.

## License

By contributing, you agree your contributions are licensed under the same terms as the project (**MIT** — see `LICENSE`).
