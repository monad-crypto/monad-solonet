#!/bin/bash
set -e

MONAD_EXECUTION_CUSTOM_BIN="${MONAD_EXECUTION_CUSTOM_BIN:-monad}"
MONAD_EXECUTION_TASKSET_CPUS="${MONAD_EXECUTION_TASKSET_CPUS:-1,2,3,4,5,6,7}"
MONAD_EXECUTION_SQ_THREAD_CPU="${MONAD_EXECUTION_SQ_THREAD_CPU:-1}"

ARGS=(
    --chain=monad_devnet
    --db=/dev/triedb
    --block_db=/home/monad/monad-bft/ledger
    --statesync=/home/monad/monad-bft/statesync.sock
    --exec-event-ring=/var/lib/hugetlbfs/user/monad/pagesize-2MB/event-rings/monad-exec-events
    --trace-calls=true
    --log_level=INFO
)

read -ra EXTRA_ARGS <<<"${MONAD_EXECUTION_EXTRA_ARGS:-}"

if [[ "${MONAD_SOLONET_CPU_LIMIT}" == "true" ]]; then
  exec cpulimit --foreground -l "${MONAD_CPU_LIMIT:-50}" -- "$MONAD_EXECUTION_CUSTOM_BIN" "${ARGS[@]}" "${EXTRA_ARGS[@]}"
else
  exec taskset -c "$MONAD_EXECUTION_TASKSET_CPUS" "$MONAD_EXECUTION_CUSTOM_BIN" "${ARGS[@]}" --sq_thread_cpu="$MONAD_EXECUTION_SQ_THREAD_CPU" "${EXTRA_ARGS[@]}"
fi
