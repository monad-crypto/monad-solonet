#!/bin/bash
set -e

ARGS=(
  --ledger-path=/home/monad/monad-bft/ledger
  --forkpoint-path=/home/monad/monad-bft/config/forkpoint/forkpoint.toml
  --peers-path=/home/monad/monad-bft/config/peers.toml
  --validators-path=/home/monad/monad-bft/config/validators/validators.toml
)

exec monad-ledger-tail "${ARGS[@]}"
