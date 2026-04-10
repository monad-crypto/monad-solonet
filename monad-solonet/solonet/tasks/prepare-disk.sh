log "Prepare triedb device ($DEVICE_SIZE_GB GB)"
mkdir -p "$(dirname "$DEVICE_PATH")"
fallocate -l "${DEVICE_SIZE_GB}G" "$DEVICE_PATH"
losetup -d "$DEVICE" 2>/dev/null || true
losetup "$DEVICE" "$DEVICE_PATH"
losetup -l | grep "$DEVICE"
ln -s "$DEVICE" /dev/triedb || true

echo "Formating MPT disk (if required)"
monad-mpt --create --storage /dev/triedb

if [[ ! -f /shared/network-started ]]; then
  log "Fetching genesis forkpoint"
  cp /solonet/config/forkpoint.genesis.toml \
    /home/monad/monad-bft/config/forkpoint/forkpoint.toml

  log "Create genesis block"
  monad --chain monad_devnet \
    --db /dev/triedb \
    --block_db ./monad-bft/ledger \
    --nblocks 0 \
    --log_level INFO
fi
