log "Generate keys"

[[ -f "$PEER_FILE" ]] && {
  echo "Already existing peer file: $PEER_FILE, skip" >&2
  return
}

mkdir -p "$KEYS_PATH/$NODE_ID"
monad-keystore create \
  --key-type secp \
  --keystore-path "/shared/keys/$NODE_ID/id-secp" \
  --password "${KEYSTORE_PASSWORD}" >/opt/monad/backup/secp-backup

monad-keystore create \
  --key-type bls \
  --keystore-path "/shared/keys/$NODE_ID/id-bls" \
  --password "${KEYSTORE_PASSWORD}" >/opt/monad/backup/bls-backup

SECP_PUBKEY=$(grep "public key" /opt/monad/backup/secp-backup | cut -d " " -f4)
SECP_PRIVKEY=$(grep "private key" /opt/monad/backup/secp-backup | cut -d " " -f4)
BLS_PUBKEY=$(grep "public key" /opt/monad/backup/bls-backup | cut -d " " -f4)
BLS_PRIVKEY=$(grep "private key" /opt/monad/backup/bls-backup | cut -d " " -f4)
echo "SECP: $SECP_PUBKEY"
echo "BLS: $BLS_PUBKEY"

log "Generate node record signature"
sig_out=$(
  monad-sign-name-record \
    --address "$CONTAINER_IP_ADDRESS:8000" \
    --authenticated-udp-port 8001 \
    --direct-udp-port 8002 \
    --keystore-path "/shared/keys/$NODE_ID/id-secp" \
    --password "${KEYSTORE_PASSWORD}" \
    --self-record-seq-num 0
)
echo "$sig_out"
SELF_NAME_RECORD_SIG=$(printf '%s\n' "$sig_out" | grep '^self_name_record_sig' | cut -d'"' -f2)

log "Generate peer file"
TMP_PEER_FILE="$(mktemp)"
cat >"$TMP_PEER_FILE" <<EOF
node_name: $NODE_NAME
node_type: $NODE_TYPE
profile: $PROFILE_NAME
profile_kind: $PROFILE_KIND
stake_weight: $STAKE_WEIGHT
register_amount: $STAKING_REGISTER_AMOUNT
delegate_amount: $STAKING_DELEGATE_AMOUNT
address: $CONTAINER_IP_ADDRESS:8000
auth_port: 8001
direct_udp_port: 8002
self_record_seq_num: 0
self_name_record_sig: $SELF_NAME_RECORD_SIG
secp256k1:
  public_key: $SECP_PUBKEY
  private_key: $SECP_PRIVKEY
bls:
  public_key: $BLS_PUBKEY
  private_key: $BLS_PRIVKEY
EOF

mkdir -p "$PEERS_PATH"
cp "$TMP_PEER_FILE" "$PEER_FILE"
cat "$PEER_FILE"
