#!/usr/bin/env bash

set -euo pipefail

BIN="${MONAD_NODE_BIN:-monad-node}"
EXTRA_ARGS="${MONAD_NODE_EXTRA_ARGS:-}"
EXTRA=()

if [[ -n "${EXTRA_ARGS}" ]]; then
  read -r -a EXTRA <<<"${EXTRA_ARGS}"
fi

exec "${BIN}" "$@" "${EXTRA[@]}"
