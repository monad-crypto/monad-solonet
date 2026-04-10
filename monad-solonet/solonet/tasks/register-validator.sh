if [[ "${NODE_ID:-1}" != "1" ]]; then
  echo "NODE_ID is not 1, skipping."
  return
fi

log "Registering validators to staking contract"
if staking-cli query validator --validator-id 1 | grep -q secp; then
  echo "Validator(s) already registered, skipping."
else
  for PEER_FILE in "$PEERS_PATH"/*; do
    [ -f "$PEER_FILE" ] || continue

    NODE_TYPE="$(yq -r '.node_type' "$PEER_FILE")"
    [ "$NODE_TYPE" = "validator" ] || continue

    VALIDATOR_NAME="$(basename "$PEER_FILE" .yaml)"
    echo "Processing $VALIDATOR_NAME"

    SECP="$(yq -r '.secp256k1.private_key' "$PEER_FILE")"
    BLS="$(yq -r '.bls.private_key' "$PEER_FILE")"

    echo "Registering validator (amount: $STAKING_REGISTER_AMOUNT)"
    OUTPUT="$(
      yes y | staking-cli add-validator \
        --secp-privkey "$SECP" \
        --bls-privkey "$BLS" \
        --amount "$STAKING_REGISTER_AMOUNT" \
        --auth-address "$STAKING_AUTH"
    )" || true

    echo "$OUTPUT"

    echo "Delegating stake (amount: $STAKING_DELEGATE_AMOUNT)"
    VAL_STAKING_ID="$(echo "$OUTPUT" | grep -oE 'ID: [0-9]+' | awk '{print $2}')"
    staking-cli delegate \
      --validator-id "$VAL_STAKING_ID" \
      --amount "$STAKING_DELEGATE_AMOUNT"

    echo
    staking-cli query validator --validator-id "$VAL_STAKING_ID"
    echo
  done
fi

log "Current execution validator-set"
staking-cli query epoch
staking-cli query validator-set --type execution
