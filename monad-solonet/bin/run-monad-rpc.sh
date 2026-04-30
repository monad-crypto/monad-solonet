#!/usr/bin/env bash

set -euo pipefail

BIN="${MONAD_RPC_BIN:-monad-rpc}"
EXTRA_ARGS="${MONAD_RPC_EXTRA_ARGS:-}"
EXTRA=()

if [[ -n "${EXTRA_ARGS}" ]]; then
  read -r -a EXTRA <<<"${EXTRA_ARGS}"
fi

exec "${BIN}" "$@" "${EXTRA[@]}"
