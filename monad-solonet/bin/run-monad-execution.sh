#!/bin/bash
set -e

MONAD_EXECUTION_CUSTOM_BIN="${MONAD_EXECUTION_CUSTOM_BIN:-monad}"

ARGS=(
  --chain=monad_devnet
  --db=/dev/triedb
  --block_db=/home/monad/monad-bft/ledger
  --statesync=/home/monad/monad-bft/statesync.sock
  --exec-event-ring=/var/lib/hugetlbfs/user/monad/pagesize-2MB/event-rings/monad-exec-events
  --trace-calls=true
  --log_level=INFO
)

read -ra EXTRA_ARGS <<< "${MONAD_EXECUTION_EXTRA_ARGS:-}"
exec cpulimit --foreground -l 50 -- "$MONAD_EXECUTION_CUSTOM_BIN" "${ARGS[@]}" "${EXTRA_ARGS[@]}"
