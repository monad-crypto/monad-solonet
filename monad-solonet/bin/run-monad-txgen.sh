#!/bin/bash
set -e

export RUST_LOG="${RUST_LOG:-debug,h2=warn,tower=warn,opentelemetry_sdk=warn,opentelemetry-otlp=warn}"

exec monad-txgen --config-file /solonet/config/txgen.toml
