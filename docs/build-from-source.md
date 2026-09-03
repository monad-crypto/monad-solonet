# Build Monad from source

Solonet supports three build modes, controlled by the `target` in `docker-compose.yaml`:

| Target | Description |
|---|---|
| `install-apt` | Install the official Monad APT package (default) |
| `install-remote` | Build from a remote git repository (branch, tag, or commit) |
| `install-local` | Build from a local source directory on your machine |

---

## Prerequisites

All source builds (`install-remote` and `install-local`) require the `monad-builder` Docker image, which contains the full Rust + C++ toolchain used to compile Monad.

Build it once from the upstream repo's Dockerfile:

```sh
cd monad-solonet/source/
make monad-builder
```

By default this fetches the builder Dockerfile tagged at `v0.16.2`. To use a different ref:

```sh
make monad-builder MONAD_BUILDER_REF=v0.16.2
```

---

## Option 1 — Official APT package (default)

Uncomment the `install-apt` block in `docker-compose.yaml`:

```yaml
build:
  context: monad-solonet
  target: install-apt
  args:
    MONAD_VERSION: 0.16.2
```

Then start Solonet:

```sh
docker compose up --build
```

---

## Option 2 — Build from remote source

Fetches and builds a specific branch, tag, or commit directly inside Docker. No local checkout needed.

Uncomment the `install-remote` block in `docker-compose.yaml`:

```yaml
build:
  context: monad-solonet
  target: install-remote
  args:
    MONAD_BFT_REPO_URL: "https://github.com/category-labs/monad-bft.git"
    MONAD_BFT_REPO_TARGET: "v0.16.2"   # branch, tag, or full commit hash
```

Then start Solonet:

```sh
docker compose up --build
```

---

## Option 3 — Build from local source

Builds from a source directory on your machine. Useful for iterating on local changes.

### 1. Clone the repository

```sh
cd monad-solonet/source/
make clone-monad-bft
```

This does a shallow clone of `monad-bft` into `monad-solonet/source/monad-bft/`, fetching only the top-level source and the `monad-execution` submodule. Keeping the checkout shallow keeps the Docker build context small.

That location is only a convention. The source is passed as a **named build context**, so it can live anywhere on the host: a checkout you already have, on another disk, outside this repository.

To clone a specific branch or tag:

```sh
make clone-monad-bft MONAD_BFT_REF=v0.16.2
```

### 2. Configure docker-compose.yaml

Uncomment the `install-local` block in `docker-compose.yaml`:

```yaml
build:
  context: monad-solonet
  target: install-local
  additional_contexts:
    monad-bft-src: ./monad-solonet/source/
```

`monad-bft-src` is the name `builder-local` copies from
(`COPY --from=monad-bft-src monad-bft/ /app/monad-bft/`). Because it is its own context,
the path is free: anywhere on the host, absolute or relative to the compose
file. This is the one way to build from a source tree outside the main build
context. Docker cannot `COPY` from outside it, and will not follow a symlink
out of it either.

### 3. Start Solonet

```sh
docker compose up --build
```

---

## Build caching

Source builds use Docker BuildKit cache mounts to speed up incremental rebuilds:

- **Cargo registry and git** — Rust dependency downloads are cached across builds, so only changed crates are re-fetched

On a clean build, compilation takes a while (Rust + C++ are both full builds). Subsequent builds that only change Rust dependencies benefit from the cache; source changes always trigger a full recompile.

### Cache management

Force a full rebuild without cache:

```sh
docker compose up --build --no-cache
```

Inspect BuildKit cache mounts:

```sh
docker buildx du --verbose --filter type=exec.cachemount
```

Prune only the build cache mounts (leaves image layers intact):

```sh
docker buildx prune -f --filter type=exec.cachemount
```
