#!/bin/bash
set -e

export RUST_LOG="${RUST_LOG:-debug,h2=warn,tower=warn,opentelemetry_sdk=warn,opentelemetry-otlp=warn}"

read -ra EXTRA_ARGS <<< "${MONAD_TXGEN_EXTRA_ARGS:-}"
exec monad-txgen --config-file /solonet/config/txgen.toml "${EXTRA_ARGS[@]}"
