#!/bin/sh
set -eu

BLOCKLIST_TYPE="${BLOCKLIST_TYPE:-ssh}"
BLOCKLIST_TYPES="${BLOCKLIST_TYPES:-}"
BLOCKLIST_URL_OVERRIDE="${BLOCKLIST_URL:-}"
SET_NAME="${BLOCKLIST_SET_NAME:-blocklist_de}"
CHAIN_NAME="${BLOCKLIST_CHAIN_NAME:-BLOCKLIST_INPUT}"
TARGET_PORTS="${BLOCKLIST_TARGET_PORTS:-22}"

TMP_SET="${SET_NAME}_tmp"
TMP_DIR="$(mktemp -d /tmp/blocklist.XXXXXX)"
RAW_LIST="${TMP_DIR}/blocklist_raw.txt"
CLEAN_LIST="${TMP_DIR}/blocklist_clean.txt"

log() {
  printf '%s %s\n' "[blocklist]" "$*"
}

case "$BLOCKLIST_TYPE" in
  all|ssh|mail|apache|imap|ftp|sip|bots|strongips|ircbot|bruteforcelogin) ;;
  *)
    log "invalid BLOCKLIST_TYPE '$BLOCKLIST_TYPE'"
    exit 1
    ;;
esac

validate_type() {
  case "$1" in
    all|ssh|mail|apache|imap|ftp|sip|bots|strongips|ircbot|bruteforcelogin) return 0 ;;
    *) return 1 ;;
  esac
}

if ! command -v curl >/dev/null 2>&1; then
  log "curl not found"
  exit 1
fi
if ! command -v ipset >/dev/null 2>&1; then
  log "ipset not found"
  exit 1
fi
if ! command -v iptables >/dev/null 2>&1; then
  log "iptables not found"
  exit 1
fi

trap 'rm -rf "$TMP_DIR"' EXIT

: > "$RAW_LIST"

if [ -n "$BLOCKLIST_URL_OVERRIDE" ]; then
  curl -fsSL --connect-timeout 15 --max-time 120 "$BLOCKLIST_URL_OVERRIDE" -o "$RAW_LIST"
  SOURCE_INFO="$BLOCKLIST_URL_OVERRIDE"
else
  if [ -n "$BLOCKLIST_TYPES" ]; then
    TYPES_INPUT="$BLOCKLIST_TYPES"
  else
    TYPES_INPUT="$BLOCKLIST_TYPE"
  fi

  # Accept comma/semicolon/space separated values.
  TYPES_LIST="$(printf '%s' "$TYPES_INPUT" | tr ',;' '  ')"
  SOURCE_INFO=""

  for type in $TYPES_LIST; do
    if ! validate_type "$type"; then
      log "invalid blocklist type '$type' in BLOCKLIST_TYPES/BLOCKLIST_TYPE"
      exit 1
    fi
    type_file="${TMP_DIR}/${type}.txt"
    type_url="https://lists.blocklist.de/lists/${type}.txt"
    curl -fsSL --connect-timeout 15 --max-time 120 "$type_url" -o "$type_file"
    cat "$type_file" >> "$RAW_LIST"
    if [ -n "$SOURCE_INFO" ]; then
      SOURCE_INFO="${SOURCE_INFO},${type}"
    else
      SOURCE_INFO="$type"
    fi
  done
fi

# Keep only valid IPv4 addresses.
grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' "$RAW_LIST" \
  | awk -F. '$1<=255 && $2<=255 && $3<=255 && $4<=255' \
  | sort -u > "$CLEAN_LIST"

ipset create "$SET_NAME" hash:ip family inet -exist
ipset create "$TMP_SET" hash:ip family inet -exist
ipset flush "$TMP_SET"

COUNT=0
while IFS= read -r ip; do
  [ -n "$ip" ] || continue
  ipset add "$TMP_SET" "$ip" -exist
  COUNT=$((COUNT + 1))
done < "$CLEAN_LIST"

# Atomic list replacement to remove stale IPs automatically.
ipset swap "$SET_NAME" "$TMP_SET"
ipset flush "$TMP_SET"

iptables -N "$CHAIN_NAME" 2>/dev/null || true
iptables -F "$CHAIN_NAME"

if [ -n "$TARGET_PORTS" ]; then
  iptables -A "$CHAIN_NAME" -p tcp -m multiport --dports "$TARGET_PORTS" -m set --match-set "$SET_NAME" src -j DROP
else
  iptables -A "$CHAIN_NAME" -m set --match-set "$SET_NAME" src -j DROP
fi

if ! iptables -C INPUT -j "$CHAIN_NAME" >/dev/null 2>&1; then
  iptables -I INPUT 1 -j "$CHAIN_NAME"
fi

log "updated set '$SET_NAME' from $SOURCE_INFO with $COUNT IPs"
