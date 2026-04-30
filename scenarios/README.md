# Scenarios

Scenarios are the source of truth for generated mixed-profile solonet networks.

They define:

- network settings such as `subnet`, `port_base`, and `device_id_start`
- named profiles with `profile_kind = "default" | "custom"`
- per-node `profile`, `node_type`, and `stake_weight`

Use them through `scripts/scenario`:

```sh
./scripts/scenario render scenarios/examples/3v-default.toml
./scripts/scenario up scenarios/examples/5v-mixed-custom.toml
./scripts/scenario down scenarios/examples/5v-mixed-custom.toml
```

The generated compose files are written under `generated/<scenario>/docker-compose.yaml`.

## Profile Model

- `default` profiles use the binaries baked into the image
- `custom` profiles can mount local builds and add optional env or service overrides

Profiles are named, so a network can mix several custom variants at once:

- `default`
- `custom_preload`
- `custom_exec_cache`

## Path Convention

Examples use:

- original execution tree: `/home/ubuntu/monad`
- original bft tree: `/home/ubuntu/monad-bft`
- execution binary output: `/home/ubuntu/monad/build/cmd/monad`
- bft binary output: `/home/ubuntu/monad-bft/target/release/monad-node`
- worktree convention:
  - `/home/ubuntu/monad/.worktrees/BRANCH_NAME/build/cmd/monad`
  - `/home/ubuntu/monad-bft/.worktrees/BRANCH_NAME/target/release/monad-node`

## Scenario Shape

```toml
name = "5v-mixed-custom"
subnet = "172.21.40.0/24"
port_base = 48080
device_id_start = 40
stake_unit = 100000

[profiles.default]
profile_kind = "default"
binary_origin = "image"

[profiles.custom_preload]
profile_kind = "custom"
binary_origin = "local"
monad_node = "/home/ubuntu/monad-bft/.worktrees/preload-tuning/target/release/monad-node"

[profiles.custom_preload.env]
MONAD_BFT_PRELOAD_TUNING = "1"

[[nodes]]
id = 1
node_type = "validator"
profile = "custom_preload"
stake_weight = 2
```
