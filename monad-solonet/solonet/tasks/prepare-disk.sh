log "Prepare triedb device ($DEVICE_SIZE_GB GB)"

# Create the disk file
mkdir -p "$(dirname "$DEVICE_PATH")"
fallocate -l "${DEVICE_SIZE_GB}G" "$DEVICE_PATH"

# Mount the disk file to next available loopback device
DEVICE=$(losetup --find --show "$DEVICE_PATH")

# Start a background process that holds a file descriptor
# on the device to allow auto-clear only on container exit
sleep infinity <>"$DEVICE" &

# Mark the device for auto-clear when becoming unused
losetup --detach "$DEVICE"

# Print the device information
losetup --list "$DEVICE"

# Map the device to trieDB path
ln -sfn "$DEVICE" /dev/triedb

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
