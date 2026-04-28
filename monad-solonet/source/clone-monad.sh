#!/bin/bash
set -ex

MONAD_BFT_REPO_URL="${MONAD_BFT_REPO_URL:-https://github.com/category-labs/monad-bft.git}"
MONAD_BFT_REPO_TARGET="${MONAD_BFT_REPO_TARGET:-master}"

# NOTE: monad-execution is a submodule of monad-bft
MONAD_EXECUTION_REPO_URL="${MONAD_EXECUTION_REPO_URL:-}"
MONAD_EXECUTION_REPO_TARGET="${MONAD_EXECUTION_REPO_TARGET:-}"

cd /app/monad-bft/

git init
git remote add origin "${MONAD_BFT_REPO_URL}"
git fetch --depth 1 origin "${MONAD_BFT_REPO_TARGET}"
git checkout FETCH_HEAD

if [ -n "${MONAD_EXECUTION_REPO_URL}" ]; then
  git config submodule.monad-execution.url "${MONAD_EXECUTION_REPO_URL}"
fi

git submodule update --init --depth 1 monad-execution

if [ -n "${MONAD_EXECUTION_REPO_TARGET}" ]; then
  cd monad-execution
  git fetch --depth 1 origin "${MONAD_EXECUTION_REPO_TARGET}"
  git checkout FETCH_HEAD
  cd ..
fi

git -C monad-execution submodule update --init --depth 1 --recursive
