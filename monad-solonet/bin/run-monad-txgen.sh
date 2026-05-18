#!/bin/bash
set -e

MONAD_TXGEN_CUSTOM_BIN="${MONAD_TXGEN_CUSTOM_BIN:-monad-txgen}"
export RUST_LOG="${RUST_LOG:-debug,h2=warn,tower=warn,opentelemetry_sdk=warn,opentelemetry-otlp=warn}"

read -ra EXTRA_ARGS <<< "${MONAD_TXGEN_EXTRA_ARGS:-}"
exec "$MONAD_TXGEN_CUSTOM_BIN" --config-file /solonet/config/txgen.toml "${EXTRA_ARGS[@]}"
