#!/bin/bash
set -e

export RUST_LOG="${RUST_LOG:-debug,h2=warn,tower=warn,opentelemetry_sdk=warn,opentelemetry-otlp=warn}"
export REMOTE_FORKPOINT_URL="${REMOTE_FORKPOINT_URL:-http://localhost:8082/shared/forkpoint.toml}"
export REMOTE_VALIDATORS_URL="${REMOTE_VALIDATORS_URL:-http://localhost:8082/shared/validators.toml}"

ARGS=(
  --triedb-path=/dev/triedb
  --secp-identity=/home/monad/monad-bft/config/id-secp
  --bls-identity=/home/monad/monad-bft/config/id-bls
  --node-config=/home/monad/monad-bft/config/node.toml
  --forkpoint-config=/home/monad/monad-bft/config/forkpoint/forkpoint.toml
  --wal-path=/home/monad/monad-bft/wal
  --mempool-ipc-path=/home/monad/monad-bft/mempool.sock
  --persisted-peers-path=/home/monad/monad-bft/config/peers.toml
  --control-panel-ipc-path=/home/monad/monad-bft/controlpanel.sock
  --statesync-ipc-path=/home/monad/monad-bft/statesync.sock
  --ledger-path=/home/monad/monad-bft/ledger
  --otel-endpoint="http://0.0.0.0:4317"
  --record-metrics-interval-seconds=1
  --validators-path=/home/monad/monad-bft/config/validators/validators.toml
  --keystore-password="${KEYSTORE_PASSWORD}"
)

if [[ -n "${CHAIN_CONFIG_OVERRIDE_ENABLED:-}" ]]; then
  ARGS+=(--devnet-chain-config-override=/solonet/config/chain-config.toml)
fi

exec cpulimit --foreground -l 50 -- monad-node "${ARGS[@]}"
