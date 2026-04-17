#!/usr/bin/env bash

set -ex

MONAD_VERSION="0.0.0"

export ASMFLAGS=-march=haswell
export CC=gcc-15
export CFLAGS=-march=haswell
export CXX=g++-15
export CXXFLAGS="-march=haswell"
export GIT_COMMIT_HASH=$(git rev-parse HEAD)
export GIT_TAG_VERSION=$MONAD_VERSION
export RUSTFLAGS="-A warnings"
export TRIEDB_TARGET=triedb_driver

cd /app/monad-bft/
cargo build -vv --release \
  --bin monad-node \
  --bin monad-keystore \
  --bin monad-debug-node \
  --bin monad-rpc \
  --bin monad-archiver \
  --bin monad-archive-checker \
  --bin monad-indexer \
  --bin monad-block-writer \
  --example ledger-tail \
  --example wal2json \
  --example triedb-bench \
  --example sign-name-record \
  --example txgen

cd /app/monad-bft/monad-execution/
cmake \
  -DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=TRUE \
  -DCMAKE_TOOLCHAIN_FILE:STRING=category/core/toolchains/gcc-avx2.cmake \
  -DCMAKE_BUILD_TYPE:STRING=RelWithDebInfo \
  -B /build -G Ninja
cmake --build /build --target all
