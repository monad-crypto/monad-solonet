log "Building configurations"
if [[ -f "/home/monad/monad-bft/config/node.toml" ]]; then
  echo "Already existing configuration: skip" >&2
  return
fi

log "Waiting for all peers info"
while true; do
  ready_count="$(find "$PEERS_PATH/" -maxdepth 1 -type f -name '*' | wc -l | tr -d ' ')"
  if [[ "$ready_count" -ge "$TOTAL_NODE_NUMBER" ]]; then
    break
  fi
  echo "Waiting, have ${ready_count}/${TOTAL_NODE_NUMBER} ready"
  sleep 1
done

log "Get keys from shared volume"
mkdir -p /home/monad/monad-bft/config/
mkdir -p /home/monad/monad-bft/config/forkpoint/
mkdir -p /home/monad/monad-bft/config/validators/
cp "/shared/keys/$NODE_ID/id-secp" /home/monad/monad-bft/config/id-secp
cp "/shared/keys/$NODE_ID/id-bls" /home/monad/monad-bft/config/id-bls

log "Building node.toml configuration"
gomplate \
  -f /solonet/config/node.toml.tmpl \
  -o /home/monad/monad-bft/config/node.toml \
  -c .=/shared/peers/node-"${NODE_ID}".yaml \
  -d peers=/shared/peers/
cat /home/monad/monad-bft/config/node.toml

log "Building validators.toml configuration"
gomplate \
  -f /solonet/config/validators.toml.tmpl \
  -o /home/monad/monad-bft/config/validators/validators.toml \
  -d peers=/shared/peers/
cat /home/monad/monad-bft/config/validators/validators.toml
