<p align="center">
  <img src="docs/logo.png" alt="Monad Docker Solonet Logo" width="250">
</p>


<h1 align="center">Monad Solonet</h1>

<p align="center">
  Run a full <b>Monad network</b>, locally.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/network-solonet-purple">
  <img src="https://img.shields.io/badge/docker-ready-blue">
  <img src="https://img.shields.io/badge/platform-linux-green">
  <img src="https://img.shields.io/badge/platform-macos%20arm-orange">
</p>


## Quick Start

Bootstrap a complete Monad network and run your own blockchain locally, fully containerized and reproducible.

On macOS (Apple Silicon), prepare the Linux VM:
```sh
# Install Linux virtual machine manager
brew install lima colima lima-additional-guestagents

# Start a Docker host on a Linux VM
colima start \
  --arch x86_64 \
  --cpu-type max \
  --cpu 8 \
  --memory 16 \
  --disk 300 \
  --foreground
```

Start a Monad Solonet on a Linux Docker host, using the prebuild [`monadcrypto/monad-solonet`](https://hub.docker.com/r/monadcrypto/monad-solonet) Docker image:
```sh
docker run --rm -it \
  --name solonet \
  --privileged \
  --network host \
  --ulimit nofile=16384:16384 \
  --pull always \
  monadcrypto/monad-solonet
```

## Features

- Uses `monad` official package and binaries
- Supports **single-validator**, **multi-validators**, and custom network setups
- Supports scenario-driven networks with mixed `default` and `custom` validator profiles
- Runs **natively on Linux** with Docker or on **macOS via an x86_64 Linux VM**
- Uses the official [devnet](https://github.com/category-labs/monad/blob/main/category/execution/monad/chain/monad_devnet_alloc.hpp) genesis allocation configuration
- Exposes RPC endpoint at http://localhost:8080
- Automatic node configuration and validator staking
- Pre-installed tooling: `forge`, `cast`, `staking-cli`, `monad-status`

https://github.com/user-attachments/assets/4e2fb3cb-cd05-4544-8f89-30eb0675cc20

Runtime notes:
- Epoch duration set to `10_000` blocks, about 1 hour
- Monad processes are limited to `0.5` CPU to reduce host resource usage
- TrieDB runs on a loopback disk stored inside the container
- Restarting containers preserves TrieDB data. Recreating containers resets TrieDB state.
- Static IP assignment is used to avoid DHCP drift and maintain stable node record signatures

_Disclaimer: This project is intended for **development and testing purposes only**. **Do not use in production**._

## Solonet versus other tools

Category            | Solonet                     | Public Full node ([docs](https://docs.monad.xyz/node-ops/full-node-installation))
--------------------|-----------------------------|-----------------------------
Concept             | Spin up a NETWORK           | Spin up a NODE
Purpose             | Local isolated network      | Join mainnet/testnet
Topology            | n validators, m fullnodes   | Single node
Use case            | Functional testing, dev     | Production-like usage
State               | New chain, from genesis     | Existing network, real chain state
Network type        | devnet                      | mainnet/testnet
Control             | Full control                | Limited (network rules)
Tokens              | Unlimited                   | Limited (MON, faucet)
Protocol version    | monad_dev (latest features) | Current MONAD_REVISION/EVM_REVISION
Perf realism        | ❌ Not realistic            | ✅ Realistic
Storage             | Loopback (TrieDB)           | Real disk
CPU                 | Throttled, no pinning       | No artificial limits
Binary              | Dev/custom setup            | Official/supported binaries
Env                 | Docker                      | Host
Setup style         | Flexible, dev-focused       | Follows official docs
Best machine        | Linux bare metal            | Linux bare metal
VM support          | ✅ Yes                      | ✅ Partially
macOS ARM           | ✅ QEMU VM                  | ❌ Not supported

## Scenario Workflow

The recommended way to run mixed-profile validator sets is through `scripts/scenario`.

Profiles are neutral and reusable:

- `default`: use the binaries baked into the image
- `custom`: mount one or more local binaries and optional env/config overrides

You can define any number of named custom profiles in one scenario, for example:

- `default`
- `custom_preload`
- `custom_exec_cache`

Each node then references one profile and one `stake_weight`.

Example paths use:

- original execution tree: `/home/ubuntu/monad`
- original bft tree: `/home/ubuntu/monad-bft`
- execution binary output: `/home/ubuntu/monad/build/cmd/monad`
- bft binary output: `/home/ubuntu/monad-bft/target/release/monad-node`
- worktree convention:
  - `/home/ubuntu/monad/.worktrees/BRANCH_NAME/build/cmd/monad`
  - `/home/ubuntu/monad-bft/.worktrees/BRANCH_NAME/target/release/monad-node`

Initialize a scaffold:

```sh
./scripts/scenario init \
  --name 5v-mixed-custom \
  --validators 5 \
  --custom-profile custom_preload=1:2 \
  --custom-profile custom_exec_cache=1:2
```

Render a compose file:

```sh
./scripts/scenario render scenarios/examples/5v-mixed-custom.toml
```

Start and stop the network:

```sh
./scripts/scenario up scenarios/examples/5v-mixed-custom.toml
./scripts/scenario down scenarios/examples/5v-mixed-custom.toml
```

Rendered compose files are written under `generated/<scenario>/docker-compose.yaml`.

## Run Monad Solonet networks

Requirements:
- Linux on x86_64 machine (see [instructions below](#prepare-docker-linux-vm-on-macos-apple-silicon) for macOS)
- [docker](https://get.docker.com) installed
- 4 CPU and 16GB memory
- Tested on Amazon EC2 instance `m8a.xlarge`.

1. Clone the repository
```sh
git clone git@github.com:aviggiano/monad-solonet.git ~/monad-solonet
cd ~/monad-solonet
```

2. Start the network

Start a single-validator network:
```sh
docker compose up --build
```

Start a multi-validators network:
```sh
docker compose -f networks/multi-validators.yaml up --build
```

Start a full-components network:
```sh
docker compose -f networks/full-network.yaml up --build
```

Start a scenario-driven mixed-profile network:
```sh
./scripts/scenario up scenarios/examples/5v-mixed-custom.toml
```

Start a three-validator network with two custom profiles sourced from older local worktrees:
```sh
./scripts/scenario up scenarios/examples/3v-two-custom-old-revisions.toml
```

For PR review, there is also a checked-in compose example at
`networks/3v-two-custom-old-revisions.yaml` that shows the rendered result for
that scenario.

### Reset and teardown

Stop and remove containers, including volumes:
```sh
docker compose -f NETWORK_FILE down --volumes
```

Stop a scenario-driven network:
```sh
./scripts/scenario down scenarios/examples/5v-mixed-custom.toml
```

## Prepare Docker Linux VM on macOS (Apple Silicon)

Since Monad binaries target x86_64, macOS ARM requires a Linux x86_64 virtual machine running Docker.

Requirements:
- Apple macOS
- [Homebrew](https://brew.sh) installed
- Tested on MacBook Pro, M4 Max, 48 GB memory

1. Install [Lima](https://lima-vm.io) and [Colima](https://colima.run):
```sh
brew install lima colima lima-additional-guestagents
```

2. Start the virtual machine with:
```sh
colima start --arch x86_64 --cpu-type max --cpu 8 --memory 16 --disk 300 --foreground
```

3. Verify the docker context:
```sh
docker info
```

Expected output should include:
```
 Architecture: x86_64
 CPUs: 8
 Total Memory: 15.61GiB
 Name: colima
```

### Reset and teardown

To completely remove the VM and all associated data:
```sh
colima delete --data
```
