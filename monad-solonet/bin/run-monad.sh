#!/usr/bin/env bash

set -euo pipefail

BIN="${MONAD_EXEC_BIN:-monad}"
EXTRA_ARGS="${MONAD_EXEC_EXTRA_ARGS:-}"
EXTRA=()

if [[ -n "${EXTRA_ARGS}" ]]; then
  read -r -a EXTRA <<<"${EXTRA_ARGS}"
fi

exec "${BIN}" "$@" "${EXTRA[@]}"
