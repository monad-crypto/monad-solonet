log "Upgrading monad"

CURRENT="$(dpkg-query -W -f='${Version}' monad 2>/dev/null || true)"

if [[ -z "${OVERRIDE_MONAD_VERSION:-}" ]]; then
  echo "ℹ️ Using default monad version from the image: $CURRENT"
  echo "Override monad version using OVERRIDE_MONAD_VERSION environment variable"
  echo "Example: --env OVERRIDE_MONAD_VERSION=$CURRENT"
  return
fi

echo "Upgrade monad to $OVERRIDE_MONAD_VERSION"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  --no-install-recommends \
  --allow-downgrades \
  --allow-change-held-packages \
  "monad=${OVERRIDE_MONAD_VERSION}"

echo "✅ monad upgraded to ${OVERRIDE_MONAD_VERSION}"
