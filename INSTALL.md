# Installing Fuzzy Quit

Fuzzy Quit ships as a single **`quit`** entrypoint plus vendored **`lib/*.sh`** and **`VERSION`**. You can install it with **Homebrew** (keg under the Cellar) or **from a git checkout** (symlink on `PATH`). Behavior is the same once `quit` runs; only the layout on disk differs.

| Method | Best for |
|--------|-----------|
| [**Homebrew**](#homebrew-keg-install) | Binary-style install, upgrades via `brew upgrade`, no clone |
| [**From source**](#from-source) | Hacking on the repo, pinning a branch, air‑gapped trees |
| [**Docker (smoke test only)**](#docker-homebrew-smoke-test) | Verifying the tap formula without installing on the host |

Usage, options, and platform behavior: **[README.md](README.md)**.

---

## Homebrew (keg install)

Requires [Homebrew](https://brew.sh/) (macOS or [Linux](https://docs.brew.sh/Homebrew-on-Linux)).

### Install

**One-liner** (tap is implied; common for third-party formulae):

```bash
brew install mlevin2/tap/fuzzy-quit
```

**Or** add the tap explicitly, then install by short name:

```bash
brew tap mlevin2/tap
brew install fuzzy-quit
```

**Formula source:** [github.com/mlevin2/homebrew-tap/blob/main/Formula/fuzzy-quit.rb](https://github.com/mlevin2/homebrew-tap/blob/main/Formula/fuzzy-quit.rb)  
**Tap / issues:** [github.com/mlevin2/homebrew-tap](https://github.com/mlevin2/homebrew-tap)

### Keg layout (what Homebrew places on disk)

Homebrew installs the software as a **keg** under the Cellar and exposes a **`bin/quit`** wrapper:

| Piece | Typical location |
|-------|-------------------|
| **`quit` on your `PATH`** | `$(brew --prefix)/bin/quit` → symlink into this formula’s **libexec** |
| **`quit`, `VERSION`, `lib/`** | `$(brew --prefix fuzzy-quit)/libexec/` |

The driver resolves **`FUZZY_QUIT_ROOT`** from the **real path** of the script (symlinks are followed), so the Cellar layout matches what a git checkout expects: `quit` beside `lib/` and `VERSION`.

Inspect after install:

```bash
brew --prefix fuzzy-quit
ls -la "$(brew --prefix fuzzy-quit)/libexec"
ls -la "$(brew --prefix)/bin/quit"
```

### Upgrade and uninstall

```bash
brew update
brew upgrade fuzzy-quit
```

```bash
brew uninstall fuzzy-quit
```

Optional: `brew autoremove` if you no longer need dependencies pulled in only for this formula.

### Dependencies

The formula declares a runtime dependency on **`bash`** where Homebrew provides it (e.g. Linux). Check with:

```bash
brew deps fuzzy-quit
```

### `PATH` and multiple installs

Only one `quit` binary is used per invocation—the first match on **`PATH`**.

- To prefer the **keg**: ensure Homebrew’s `bin` appears **before** a dev checkout (e.g. `eval "$(/opt/homebrew/bin/brew shellenv)"` in your shell startup).
- To prefer a **git checkout** or **~/bin** symlink: put that directory **before** Homebrew’s `bin`.

Use `which -a quit` to see candidates.

### Maintainer note (version bumps)

When you tag a new upstream release, update the formula **`url`** and **`sha256`** (archive tarball) in **`mlevin2/homebrew-tap`**, then `brew reinstall fuzzy-quit` or `brew upgrade`. See **[README.md](README.md)** → *Release checklist*.

---

## From source

```bash
git clone https://github.com/mlevin2/fuzzy-quit.git
cd fuzzy-quit
chmod +x quit
```

Put **`quit`** on your **`PATH`**. A **symlink** is recommended (the driver follows symlinks to find **`lib/`** and **`VERSION`**):

```bash
ln -sf "$(pwd)/quit" "$HOME/bin/quit"   # or any directory on your PATH
```

Confirm:

```bash
quit --version
quit --help
```

---

## Docker: Homebrew smoke test

To exercise **`brew install fuzzy-quit`** **inside a container** (does not change your host `PATH`):

```bash
bash scripts/test-homebrew-docker.sh
```

Requires Docker, outbound DNS/HTTPS, and a few minutes on first pull.

### What runs (Compose vs Dockerfile vs CI)

| Approach | Typical use |
|----------|-------------|
| **`docker-compose.brew.yml`** + bind mount | **Default.** Runs **`scripts/homebrew-smoke-inner.sh`** in **`ghcr.io/homebrew/brew`**; edit the script and re-run **without** rebuilding an image. |
| **`docker/Dockerfile.homebrew-smoke`** | **Optional.** `COPY`s the inner script into the image; use when you prefer **`docker build` / `docker run`** with no mount (e.g. sharing a fixed image digest). Rebuild after script changes. |
| **GitHub Actions `brew-smoke`** | **Optional.** Same script in the same upstream image; **not** on every push (slow, network). Runs on **workflow_dispatch** and **weekly**; use it to catch a broken tap after releases. |

A separate Dockerfile is **not required** for respectability—many projects only use Compose or a raw **`docker run … bash -c '…'`**. Offering a thin Dockerfile is mainly for teams that standardize on **`docker build`** or want an immutable image tag.

### Optional: build the smoke image yourself

```bash
docker build -f docker/Dockerfile.homebrew-smoke -t fuzzy-quit-brew-smoke .
docker run --rm fuzzy-quit-brew-smoke
```

### Testing Homebrew on the host (local)

If you are fine installing on your machine (and are not worried about colliding with a dev `quit` on **`PATH`**):

```bash
brew install mlevin2/tap/fuzzy-quit
which -a quit
quit --version
```

To prefer your checkout again, put its **`bin`** (or **`~/bin`**) **before** Homebrew’s **`bin`** in **`PATH`**, or **`brew uninstall fuzzy-quit`** when done.

---

## Docker: Linux test suite (not an install)

**`make test-linux`** / **`bash scripts/test-linux-docker.sh`** run **shellcheck** and **`tests/run.sh`** in Ubuntu; they do not install `quit` into the image for daily use. See **[README.md](README.md)** → *Running the tests*.
