#!/usr/bin/env bash

set -euo pipefail

run_task() {
  source "$(dirname "${BASH_SOURCE[0]}")/tasks/$1"
}

/usr/bin/supervisord -c /solonet/config/supervisord.conf

run_task ../lib/env.sh
run_task ../lib/helpers.sh

run_task check-system.sh
run_task upgrade-monad.sh
run_task generate-keys.sh
run_task build-config.sh
run_task prepare-disk.sh

log "Starting monad services"
start_service otelcol
start_service monad-bft
start_service monad-execution
start_service monad-rpc
run_task wait-blockchain.sh

log "Starting services"
start_service monad-ledger-tail
start_service sync-forkpoint-files

log "Services"
supervisorctl status

run_task register-validator.sh
run_task print-info.sh

tail -f /dev/null
