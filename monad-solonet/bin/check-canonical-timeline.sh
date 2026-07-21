#!/usr/bin/env bash
# Compares the primary (slot) and secondary (page) TrieDB timelines'
# computed state_root for a given block against the real header stateRoot,
# to determine which timeline is currently canonical.
#
# Usage: ./check-canonical-timeline.sh
# No arguments needed — everything is auto-detected:
#   - block_number: current height, via a raw curl eth_blockNumber call
#   - db_path: /dev/triedb
#   - ETH_RPC_URL: http://localhost:8080 (override via env var)
#
# Requires `expect` (apt-get install -y expect), `curl`, `jq`, and `monad-cli`
# on PATH. `monad-mpt` is optional but strongly recommended — without it,
# this can't tell whether primary/secondary have been promoted and falls
# back to assuming primary=slot, secondary=page.
set -euo pipefail

if ! command -v expect >/dev/null 2>&1; then
  echo "expect is not installed. Install it with: apt-get install -y expect" >&2
  exit 1
fi

# slot/ethereum = red, page/monad = green. On by default — not gated on
# `[ -t 1 ]`, since that's false under `docker exec -i` (no `-t`), which is
# how this script is normally invoked (`cat script | docker exec -i ... bash`).
# Set NO_COLOR=1 to opt out (https://no-color.org/), e.g. when redirecting to
# a log file.
if [ -n "${NO_COLOR:-}" ]; then
  RED=''
  GREEN=''
  YELLOW=''
  BOLD=''
  DIM=''
  RESET=''
else
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
fi

DB_PATH="${DB_PATH:-/dev/triedb}"
ETH_RPC_URL="${ETH_RPC_URL:-http://localhost:8080}"

HEX_BN=$(curl -s -X POST "$ETH_RPC_URL" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","id":1}' | jq -r '.result')
VERSION=$(($(printf "%d" "$HEX_BN") - 10))

HEX_VERSION=$(printf "0x%x" "$VERSION")
EXPECTED_ROOT=$(curl -s -X POST "$ETH_RPC_URL" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"${HEX_VERSION}\",false],\"id\":1}" \
  | jq -r '.result.stateRoot // empty')
if [ -z "$EXPECTED_ROOT" ]; then
  echo "could not fetch stateRoot for block $VERSION from $ETH_RPC_URL" >&2
  exit 1
fi

# Drives one `monad-cli --it` session (needs a real pty, hence `expect`) to
# the given block version/timeline and prints its computed state Merkle root
# on stdout. Returns non-zero if the timeline couldn't be queried at all
# (e.g. secondary not active) rather than treating "no root found" as fatal.
query_root() {
  local secondary_flag="$1"
  local output
  set +e
  output=$(expect -c "
    set timeout 30
    spawn monad-cli --db {$DB_PATH} --it $secondary_flag
    expect \"(monaddb) \"
    send \"version $VERSION\r\"
    expect \"(monaddb) \"
    send \"finalized\r\"
    expect \"(monaddb) \"
    send \"table state\r\"
    expect \"(monaddb) \"
    send \"exit\r\"
    expect eof
  " 2>&1 </dev/null)
  local status=$?
  set -e
  [ $status -eq 0 ] || return 1
  # `grep`/`head` under pipefail can report failure even on a real match
  # (head closing the pipe early SIGPIPEs grep); `|| true` treats that as
  # "nothing found" rather than a fatal error.
  echo "$output" | { grep -oE 'Merkle root is 0x[0-9a-fA-F]+' || true; } | head -1 | awk '{print $NF}'
}

# "primary"/"secondary" are just role labels (which physical ring currently
# holds the role) — NOT tied to an encoding. Whichever ring is primary can be
# slot or page depending on whether `monad-mpt --promote-secondary` has ever
# run. So don't assume; ask `monad-mpt` which kind each ring actually is.
#
# monad-mpt's `Secondary:` section only prints when
# aux.metadata_ctx().timeline_active(secondary) is true (see
# print_db_history_summary in cli_tool_impl.cpp) — that's the authoritative
# signal for whether the secondary timeline actually exists. We do NOT infer
# this from whether `monad-cli --secondary` succeeds: it apparently opens
# fine even when the secondary ring was never activated (garbage/empty data,
# no error), so that would silently misreport init as phase A.
declare -A KIND
SECONDARY_ACTIVE=false
if command -v monad-mpt >/dev/null 2>&1; then
  MPT_OUT=$(monad-mpt --storage "$DB_PATH" 2>&1 || true)
  KIND[primary]=$(echo "$MPT_OUT" | awk '/Primary:/{f=1} /Secondary:/{f=0} f && /State machine kind:/{print $NF; exit}')
  KIND[secondary]=$(echo "$MPT_OUT" | awk '/Secondary:/{f=1} f && /State machine kind:/{print $NF; exit}')
  echo "$MPT_OUT" | grep -q '^ *Secondary:' && SECONDARY_ACTIVE=true
else
  echo "${YELLOW}warning: monad-mpt not found — cannot reliably tell whether the secondary timeline is active; phase detection may be wrong${RESET}" >&2
fi
# Fall back to the pre-promotion default if monad-mpt is unavailable or its
# output didn't parse, rather than silently mislabeling.
if [ -z "${KIND[primary]:-}" ]; then
  echo "${YELLOW}warning: could not determine primary's real encoding via monad-mpt — assuming slot/ethereum${RESET}" >&2
  KIND[primary]="ethereum"
fi
if [ -z "${KIND[secondary]:-}" ]; then
  KIND[secondary]="monad"
fi

declare -A ROOTS COLOR LABEL
for timeline in primary secondary; do
  if [ "${KIND[$timeline]}" = monad ]; then
    COLOR[$timeline]="$GREEN"
    LABEL[$timeline]="$timeline (page/monad)"
  else
    COLOR[$timeline]="$RED"
    LABEL[$timeline]="$timeline (slot/ethereum)"
  fi
done

echo "block: $VERSION"
echo "headerStateRoot: ${EXPECTED_ROOT}"
for timeline in primary secondary; do
  color="${COLOR[$timeline]}"
  label="${LABEL[$timeline]}"
  if [ "$timeline" = secondary ] && [ "$SECONDARY_ACTIVE" = false ]; then
    ROOTS[$timeline]=""
    printf "%-24s %sunavailable (not active on this node)%s\n" "$label" "$DIM" "$RESET"
    continue
  fi
  flag=""; [ "$timeline" = secondary ] && flag="--secondary"
  if root=$(query_root "$flag"); then
    ROOTS[$timeline]="$root"
    if [ -z "$root" ]; then
      printf "%-24s %s<not found>%s\n" "$label" "$YELLOW" "$RESET"
    else
      printf "%-24s %s%s%s\n" "$label" "$color" "$root" "$RESET"
    fi
  else
    ROOTS[$timeline]=""
    printf "%-24s %squery failed%s\n" "$label" "$YELLOW" "$RESET"
  fi
done

CANONICAL=""
if [ "${ROOTS[primary],,}" == "${EXPECTED_ROOT,,}" ]; then
  CANONICAL=primary
  echo "=> CANONICAL: ${COLOR[primary]}${LABEL[primary]}${RESET}"
elif [ -n "${ROOTS[secondary]:-}" ] && [ "${ROOTS[secondary],,}" == "${EXPECTED_ROOT,,}" ]; then
  CANONICAL=secondary
  echo "=> CANONICAL: ${COLOR[secondary]}${LABEL[secondary]}${RESET}"
elif [ "$SECONDARY_ACTIVE" = false ]; then
  echo "${YELLOW}=> primary did not match, and secondary timeline is unavailable — cannot determine canonical source${RESET}"
else
  echo "${YELLOW}=> NEITHER matched — check version/db path are correct${RESET}"
fi

# INIT:  no secondary yet, primary is slot/ethereum
# A:     dual-write active, canonical still primary (slot/ethereum) — pre-fork
# B:     dual-write active, canonical now secondary (page/monad) — post-fork
# C:     no secondary anymore, primary is page/monad — promoted, migration done
if [ "$SECONDARY_ACTIVE" = false ]; then
  if [ "${KIND[primary]}" = monad ]; then
    PHASE="C"
    STATUS="primary is page/monad (promoted, migration complete)"
  else
    PHASE="INIT"
    STATUS="primary is slot/ethereum, no secondary active"
  fi
else
  case "$CANONICAL" in
    primary)   PHASE="A"; STATUS="secondary active, canonical is still primary (slot/ethereum) — pre-fork" ;;
    secondary) PHASE="B"; STATUS="secondary active, canonical is now secondary (page/monad) — post-fork" ;;
    *)         PHASE="unknown"; STATUS="secondary active but canonical could not be determined" ;;
  esac
fi
echo "${BOLD}Phase: ${PHASE}${RESET}"
echo "Status: ${STATUS}"
