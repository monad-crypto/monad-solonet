#!/bin/bash
set -e

MONAD_TXGEN_CUSTOM_BIN="${MONAD_TXGEN_CUSTOM_BIN:-monad-txgen}"
export RUST_LOG="${RUST_LOG:-debug,h2=warn,tower=warn,opentelemetry_sdk=warn,opentelemetry-otlp=warn}"

if [[ -n "${MONAD_TXGEN_PROFILE:-}" ]]; then
  TXGEN_CONFIG_FILE="/solonet/config/txgen/profiles/${MONAD_TXGEN_PROFILE}"
  if [[ ! -f "$TXGEN_CONFIG_FILE" ]]; then
    echo "ERROR: txgen profile not found: $TXGEN_CONFIG_FILE" >&2
    exit 1
  fi
else
  TXGEN_CONFIG_FILE="/solonet/config/txgen/config.toml"
fi

read -ra EXTRA_ARGS <<< "${MONAD_TXGEN_EXTRA_ARGS:-}"
exec "$MONAD_TXGEN_CUSTOM_BIN" --config-file "$TXGEN_CONFIG_FILE" "${EXTRA_ARGS[@]}"
