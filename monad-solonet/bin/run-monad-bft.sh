#!/bin/bash
set -e

MONAD_BFT_CUSTOM_BIN="${MONAD_BFT_CUSTOM_BIN:-monad-node}"
MONAD_BFT_TASKSET_CPUS="${MONAD_BFT_TASKSET_CPUS:-8,9,10,11}"
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
    ARGS+=(--devnet-chain-config-override=/home/monad/monad-bft/config/chain-config.toml)
fi

read -ra EXTRA_ARGS <<<"${MONAD_BFT_EXTRA_ARGS:-}"

if [[ "${MONAD_SOLONET_CPU_LIMIT}" == "true" ]]; then
  exec cpulimit --foreground -l "${MONAD_CPU_LIMIT:-50}" -- "$MONAD_BFT_CUSTOM_BIN" "${ARGS[@]}" "${EXTRA_ARGS[@]}"
else
  exec taskset -c "$MONAD_BFT_TASKSET_CPUS" "$MONAD_BFT_CUSTOM_BIN" "${ARGS[@]}" --statesync-sq-thread-cpu=8 "${EXTRA_ARGS[@]}"
fi
