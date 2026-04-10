#!/usr/bin/bash

set -e

SRC=/home/monad/monad-bft/config/forkpoint/forkpoint.toml
DST=/shared/forkpoint.toml

copy_forkpoint() {
  SRC_ROUND=$(awk -F' = ' '/^round = / {print $2; exit}' "$SRC")
  DST_ROUND=$(awk -F' = ' '/^round = / {print $2; exit}' "$DST" 2>/dev/null || echo 0)

  if ((SRC_ROUND > DST_ROUND)); then
    echo "Updating forkpoint.toml ($DST_ROUND -> $SRC_ROUND)"
    cp "$SRC" "$DST"
  else
    echo "Not updating forkpoint.toml (source round $SRC_ROUND <= destination round $DST_ROUND)"
  fi
}

while true; do
  copy_forkpoint
  cp /home/monad/monad-bft/config/validators/validators.toml /shared/validators.toml
  sleep 10
done
