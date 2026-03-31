start_service() {
  local svc="$1"

  if supervisorctl start "$svc"; then
    echo
  else
    echo "❌ $svc failed to start, showing logs:"
    supervisorctl tail -100 "$svc"
    return 1
  fi
}

get_block() {
  curl -s \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    "http://localhost:8080" |
    jq -r '.result' |
    xargs printf "%d\n"
}

log() {
  msg="$*"
  ts=$(date +"%Y-%m-%d %H:%M:%S")

  printf "\n"
  printf "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
  printf "\033[1;32m[%s]\033[0m \033[1m%s\033[0m\n" "$ts" "$msg"
  printf "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
}

fail() {
  echo "❌ mismatch: $1"
  return 1
}

is_privileged() {
  # Needs /proc mounted (it is by default in Docker)
  # Looks for the "all capabilities granted" mask inside the container.
  local capeff
  capeff="$(awk '/^CapEff:/ {print $2}' /proc/self/status)"

  # On most kernels, privileged containers end up with all capability bits set.
  # This constant works on typical modern kernels.
  if [[ "$capeff" == "0000003fffffffff" || "$capeff" == "000001ffffffffff" || "$capeff" == "ffffffffffffffff" ]]; then
    return 0
  fi

  # Fallback: if capsh exists, check for a strong signal capability
  if command -v capsh >/dev/null 2>&1; then
    capsh --print 2>/dev/null | grep -q 'cap_sys_admin' && return 0
  fi

  return 1
}

check_sysctl() {
  local KEY="$1"
  local EXPECTED="$2"
  local PATH="/proc/sys/${KEY//./\/}"

  if [[ ! -f "$PATH" ]]; then
    echo "$KEY not visible inside container"
    return
  fi

  local CURRENT
  read -r CURRENT <"$PATH"

  CURRENT=${CURRENT//$'\t'/ }
  EXPECTED=${EXPECTED//$'\t'/ }

  if [[ "$CURRENT" != "$EXPECTED" ]]; then
    echo "⚠️ $KEY unexpected value: $CURRENT (expected $EXPECTED)"
  else
    echo "✅ $KEY = $CURRENT"
  fi
}

is_1g_hugepages_cpu() {
  grep -q pdpe1gb /proc/cpuinfo
}

show_rpc_methods() {
  tail -n 0 -f /var/log/monad-rpc.log | jq --unbuffered -r \
    'select(.fields.body) | .fields.body | ltrimstr("b") | fromjson | fromjson | . as $req | $req.method, ($req.params // [] | map("\t" + tostring)[])'
}
