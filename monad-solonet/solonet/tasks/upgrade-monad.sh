log "Upgrading monad"

CURRENT="$(dpkg-query -W -f='${Version}' monad 2>/dev/null || true)"

if [[ -z "${MONAD_VERSION_OVERRIDE:-}" ]]; then
  echo "ℹ️ Using default monad version from the image: $CURRENT"
  echo "Override monad version using MONAD_VERSION_OVERRIDE environment variable"
  echo "Example: --env MONAD_VERSION_OVERRIDE=$CURRENT"
  echo "Note: this can break if incompatible with this version of solonet"
  return
fi

echo "Upgrade monad to $MONAD_VERSION_OVERRIDE"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  --no-install-recommends \
  --allow-downgrades \
  --allow-change-held-packages \
  "monad=${MONAD_VERSION_OVERRIDE}"

echo "✅ monad upgraded to ${MONAD_VERSION_OVERRIDE}"
