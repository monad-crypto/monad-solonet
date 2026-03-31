log "Waiting for blockchain to produce blocks"
echo "Block production can take up to 3 minutes to start"

while true; do
  START_BLOCK=$(get_block 2>/dev/null || echo "")
  if ((START_BLOCK > 0)); then
    break
  fi
  sleep 1
done

while true; do
  CURRENT_BLOCK=$(get_block 2>/dev/null || echo "")
  if [[ -z "$CURRENT_BLOCK" ]]; then
    continue
  fi
  PRODUCED=$((CURRENT_BLOCK - START_BLOCK))
  echo "Current block: $CURRENT_BLOCK"
  if ((PRODUCED >= 10)); then
    echo "Blockchain produced 10 blocks"
    break
  fi
  sleep 1
done

log "Waiting for all nodes to be up"
touch /shared/node-${NODE_ID}-started
while [ "$(ls /shared/node-*-started 2>/dev/null | wc -l)" -lt "$TOTAL_NODE_NUMBER" ]; do
  sleep 1
done
touch /shared/network-started
