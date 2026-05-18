#!/bin/bash
set -e

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
exec cpulimit --foreground -l 50 -- monad-rpc "${ARGS[@]}" "${EXTRA_ARGS[@]}"
