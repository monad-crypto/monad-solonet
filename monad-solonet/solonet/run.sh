#!/usr/bin/env bash

set -euo pipefail

run_task() {
  source "$(dirname "${BASH_SOURCE[0]}")/tasks/$1"
}

run_task ../lib/env.sh
run_task ../lib/helpers.sh

# When stopping the container and we take longer than the default 10s to stop, docker will SIGKILL the process
# and we won't have a chance to clean up the supervisord socket. So we remove it here on startup to avoid errors.
[[ -S /var/run/supervisor.sock ]] && rm -f /var/run/supervisor.sock
/usr/bin/supervisord -c /solonet/config/supervisord.conf &
SUPERVISORD_PID=$!

shutdown() {
  log "Received termination signal, shutting down supervisord"
  kill -TERM "$SUPERVISORD_PID" 2>/dev/null || true
  wait "$SUPERVISORD_PID" 2>/dev/null || true
  exit 0
}
trap shutdown TERM INT

# Wait for supervisord's control socket before issuing supervisorctl commands
until [[ -S /var/run/supervisor.sock ]]; do sleep 0.1; done

run_task check-system.sh
run_task upgrade-monad.sh
run_task generate-keys.sh
run_task build-config.sh
run_task prepare-disk.sh

log "Starting monad services"
start_service otelcol
start_service monad-rpc
start_service monad-execution
start_service monad-bft

log "Waiting for the blockchain to start"
run_task wait-blockchain.sh

log "Starting services"
start_service monad-ledger-tail
start_service sync-forkpoint-files

if [[ "${MONAD_TXGEN_AUTO_START:-false}" == "true" ]]; then
  start_service monad-txgen
fi

log "Services"
supervisorctl status || true

run_task register-validator.sh
run_task print-info.sh

wait "$SUPERVISORD_PID"
