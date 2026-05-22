#!/bin/bash
set -e

MONAD_LEDGER_TAIL_CUSTOM_BIN="${MONAD_LEDGER_TAIL_CUSTOM_BIN:-monad-ledger-tail}"

ARGS=(
  --ledger-path=/home/monad/monad-bft/ledger
  --forkpoint-path=/home/monad/monad-bft/config/forkpoint/forkpoint.toml
  --peers-path=/home/monad/monad-bft/config/peers.toml
  --validators-path=/home/monad/monad-bft/config/validators/validators.toml
)

read -ra EXTRA_ARGS <<< "${MONAD_LEDGER_TAIL_EXTRA_ARGS:-}"
exec "$MONAD_LEDGER_TAIL_CUSTOM_BIN" "${ARGS[@]}" "${EXTRA_ARGS[@]}"
