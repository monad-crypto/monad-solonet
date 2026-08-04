#!/bin/bash
set -e

MONAD_RPC_CUSTOM_BIN="${MONAD_RPC_CUSTOM_BIN:-monad-rpc}"
MONAD_RPC_TASKSET_CPUS="${MONAD_RPC_TASKSET_CPUS:-12,13,14,15}"
export RUST_LOG="${RUST_LOG:-debug,h2=warn,tower=warn,opentelemetry_sdk=warn,opentelemetry-otlp=warn}"

ARGS=(
    --rpc-port=8080
    --ipc-path=/home/monad/monad-bft/mempool.sock
    --triedb-path=/dev/triedb
    --otel-endpoint="http://0.0.0.0:4317"
    --node-config=/home/monad/monad-bft/config/node.toml
    --exec-event-path=/var/lib/hugetlbfs/user/monad/pagesize-2MB/event-rings/monad-exec-events
    --allow-unprotected-txs
    --ws-enabled
)

read -ra EXTRA_ARGS <<<"${MONAD_RPC_EXTRA_ARGS:-}"

if [[ "${MONAD_SOLONET_CPU_LIMIT}" == "true" ]]; then
  exec cpulimit --foreground -l "${MONAD_CPU_LIMIT:-50}" -- "$MONAD_RPC_CUSTOM_BIN" "${ARGS[@]}" "${EXTRA_ARGS[@]}"
else
  exec taskset -c "$MONAD_RPC_TASKSET_CPUS" "$MONAD_RPC_CUSTOM_BIN" "${ARGS[@]}" "${EXTRA_ARGS[@]}"
fi
