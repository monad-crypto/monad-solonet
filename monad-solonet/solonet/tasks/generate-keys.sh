log "Generate keys"

[[ -f "$PEER_FILE" ]] && {
  echo "Already existing peer file: $PEER_FILE, skip" >&2
  return
}

mkdir -p "$KEYS_PATH/$NODE_ID"
mkdir -p /opt/monad/backup

if [[ -n "${SECP_IKM:-}" && -n "${BLS_IKM:-}" ]]; then
  log "Restoring node identity from IKM secrets"

  monad-keystore import \
    --ikm "$SECP_IKM" \
    --password "${KEYSTORE_PASSWORD}" \
    --keystore-path "/shared/keys/$NODE_ID/id-secp" \
    --key-type secp > /opt/monad/backup/secp-backup

  monad-keystore import \
    --ikm "$BLS_IKM" \
    --password "${KEYSTORE_PASSWORD}" \
    --keystore-path "/shared/keys/$NODE_ID/id-bls" \
    --key-type bls > /opt/monad/backup/bls-backup

elif [[ -z "${SECP_IKM:-}" && -z "${BLS_IKM:-}" ]]; then
  log "Generating fresh node identity"

  monad-keystore create \
    --key-type secp \
    --keystore-path "/shared/keys/$NODE_ID/id-secp" \
    --password "${KEYSTORE_PASSWORD}" > /opt/monad/backup/secp-backup

  monad-keystore create \
    --key-type bls \
    --keystore-path "/shared/keys/$NODE_ID/id-bls" \
    --password "${KEYSTORE_PASSWORD}" > /opt/monad/backup/bls-backup

else
  echo "ERROR: SECP_IKM and BLS_IKM must both be set or both be unset." >&2
  exit 1
fi

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
