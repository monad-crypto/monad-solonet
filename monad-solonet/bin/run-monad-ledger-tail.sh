#!/bin/bash
set -e

ARGS=(
  --ledger-path=/home/monad/monad-bft/ledger
  --forkpoint-path=/home/monad/monad-bft/config/forkpoint/forkpoint.toml
  --peers-path=/home/monad/monad-bft/config/peers.toml
  --validators-path=/home/monad/monad-bft/config/validators/validators.toml
)

read -ra EXTRA_ARGS <<< "${MONAD_LEDGER_TAIL_EXTRA_ARGS:-}"
exec monad-ledger-tail "${ARGS[@]}" "${EXTRA_ARGS[@]}"
