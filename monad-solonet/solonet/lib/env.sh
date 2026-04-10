export NODE_ID=${NODE_ID:-1}
export NODE_NAME="node-$NODE_ID"

export AUTO_DEVICE_ID_START=${DEVICE_ID_START:-2}
export AUTO_DEVICE_ID="$((AUTO_DEVICE_ID_START + NODE_ID))"
export DEVICE_ID="${DEVICE_ID:-$AUTO_DEVICE_ID}"
export DEVICE_PATH=/root/triedb.img
export DEVICE="/dev/loop$DEVICE_ID"
export DEVICE_SIZE_GB="6"

export CONTAINER_IP_ADDRESS=$(hostname -i 2>/dev/null | awk '{ if (NF==1) print $1; else print "0.0.0.0" }')
export KEYS_PATH="/shared/keys/"
export NODE_TYPE=${NODE_TYPE:-validator} # values: validator, dedicated, public
export OVERRIDE_MONAD_VERSION=${OVERRIDE_MONAD_VERSION:-}
export PEERS_PATH="/shared/peers"
export PEER_FILE="${PEERS_PATH}/${NODE_NAME}.yaml"
export RUST_LOG=debug,h2=warn,tower=warn,opentelemetry_sdk=warn,opentelemetry-otlp=warn
export STAKING_AUTH="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
export STAKING_DELEGATE_AMOUNT="10000000"
export STAKING_REGISTER_AMOUNT="100000"
export TOTAL_NODE_NUMBER=${TOTAL_NODE_NUMBER:-1}
