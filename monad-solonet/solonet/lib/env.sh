export KEYSTORE_PASSWORD="${KEYSTORE_PASSWORD:-password}"
export NODE_ID=${NODE_ID:-1}
export NODE_NAME="node-$NODE_ID"

export DEVICE_PATH="${DEVICE_PATH:-/root/triedb.img}"
export DEVICE_SIZE_GB="${DEVICE_SIZE_GB:-6}"

export CONTAINER_IP_ADDRESS=$(hostname -i 2>/dev/null | awk '{ if (NF==1) print $1; else print "0.0.0.0" }')
export KEYS_PATH="/shared/keys/"
export NODE_TYPE="${NODE_TYPE:-validator}" # values: validator, dedicated, public
export PROFILE_NAME="${PROFILE_NAME:-default}"
export PROFILE_KIND="${PROFILE_KIND:-default}"
export STAKE_WEIGHT="${STAKE_WEIGHT:-1}"
export MONAD_VERSION_OVERRIDE=${MONAD_VERSION_OVERRIDE:-}
export PEERS_PATH="/shared/peers"
export PEER_FILE="${PEERS_PATH}/${NODE_NAME}.yaml"
export RUST_LOG=debug,h2=warn,tower=warn,opentelemetry_sdk=warn,opentelemetry-otlp=warn
export STAKING_AUTH="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
export STAKING_DELEGATE_AMOUNT="10000000"
export STAKING_REGISTER_AMOUNT="100000"
export TOTAL_NODE_NUMBER=${TOTAL_NODE_NUMBER:-1}
export MONAD_NODE_BIN="${MONAD_NODE_BIN:-monad-node}"
export MONAD_EXEC_BIN="${MONAD_EXEC_BIN:-monad}"
export MONAD_RPC_BIN="${MONAD_RPC_BIN:-monad-rpc}"
export MONAD_NODE_EXTRA_ARGS="${MONAD_NODE_EXTRA_ARGS:-}"
export MONAD_EXEC_EXTRA_ARGS="${MONAD_EXEC_EXTRA_ARGS:-}"
export MONAD_RPC_EXTRA_ARGS="${MONAD_RPC_EXTRA_ARGS:-}"
