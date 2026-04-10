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
colima start --arch x86_64 --cpu-type max --cpu 8 --memory 16 --disk 300 --foreground
```

Start a Monad Solonet on a Linux Docker host, using the prebuild [`monadcrypto/monad-solonet`](https://hub.docker.com/r/monadcrypto/monad-solonet) Docker image:
```sh
docker run --name solonet --rm -it --privileged --network host --pull always monadcrypto/monad-solonet
```

## Features

- Uses `monad` official package and binaries
- Supports **single-validator**, **multi-validators**, and custom network setups
- Runs **natively on Linux** with Docker or on **macOS via an x86_64 Linux VM**
- Uses the official [devnet](https://github.com/category-labs/monad/blob/main/category/execution/monad/chain/monad_devnet_alloc.hpp) genesis allocation configuration
- Exposes RPC endpoint at http://localhost:8080
- Automatic node configuration and validator staking
- Pre-installed tooling: `forge`, `cast`, `staking-cli`, `monad-status`


<video src="https://github.com/user-attachments/assets/d6233ed0-5b6b-4e55-9109-3af283cda4a4" width="700" controls></video>

Runtime notes:
- Epoch duration set to `10_000` blocks, about 1 hour
- Monad processes are limited to `0.5` CPU to reduce host resource usage
- TrieDB runs on a loopback disk stored inside the container
- Restarting containers preserves TrieDB data. Recreating containers resets TrieDB state.
- Static IP assignment is used to avoid DHCP drift and maintain stable node record signatures

_Disclaimer: This project is intended for **development and testing purposes only**. **Do not use in production**._


## Run Monad Solonet networks

Requirements:
- Linux on x86_64 machine (see [instructions below](#prepare-docker-linux-vm-on-macos-apple-silicon) for macOS)
- [docker](https://get.docker.com) installed
- 4 CPU and 16GB memory
- Tested on Amazon EC2 instance `m8a.xlarge`.

1. Clone the repository
```sh
git clone https://github.com/monad-developers/monad-docker-solonet.git
cd monad-docker-solonet
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

### Reset and teardown

Stop and remove containers, including volumes:
```sh
docker compose -f NETWORK_FILE down --volumes
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
