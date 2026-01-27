#!/usr/bin/env bash
# tcp_connect_ms.sh
# Measure TCP connect latency (3-way handshake) in milliseconds for a given host(ip/domain) and port.
# Usage: ./tcp_connect_ms.sh <host> <port>
#
# Output:
#   - On success: prints a single integer millisecond value to STDOUT
#   - If host is a domain with no A record: prints -1 to STDOUT and exits 0
#   - On failure: prints an error message to STDERR and exits non-zero
#
# Notes:
#   - Uses bash /dev/tcp to trigger kernel connect().
#   - Uses dig to precheck A record for domain names (skip for IPs).
#   - Includes minimal validation and a timeout to avoid hanging.

set -Eeuo pipefail

log_err() { printf '[%s] %s\n' "ERROR" "$*" >&2; }
usage() {
  cat >&2 <<'EOF'
Usage:
  tcp_connect_ms.sh <host> <port>

Examples:
  tcp_connect_ms.sh 1.2.3.4 443
  tcp_connect_ms.sh example.com 6379

Exit codes:
  0  success (including domain with no A record => output -1)
  2  bad arguments / validation error
  3  connect failed / timeout
EOF
}

is_ipv4() {
  # strict-ish IPv4 check: 0-255 each octet
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r o1 o2 o3 o4 <<<"$ip"
  for o in "$o1" "$o2" "$o3" "$o4"; do
    [[ "$o" =~ ^[0-9]+$ ]] || return 1
    (( o >= 0 && o <= 255 )) || return 1
  done
  return 0
}

has_a_record() {
  # Returns 0 if A record exists, 1 if not (NXDOMAIN/NODATA/timeout treated as no A)
  # Use +short so output is only IPs; any non-empty means at least one A answer
  local name="$1"
  local out
  out="$(dig +time=1 +tries=1 +short A "$name" 2>/dev/null | tr -d '[:space:]' || true)"
  [[ -n "$out" ]]
}

# --- argument parsing ---
if [[ $# -ne 2 ]]; then
  usage
  exit 2
fi

HOST="$1"
PORT="$2"

if [[ -z "${HOST}" ]]; then
  log_err "host is empty"
  exit 2
fi

# Port validation: 1..65535, numeric only
if ! [[ "${PORT}" =~ ^[0-9]+$ ]]; then
  log_err "port must be numeric: '${PORT}'"
  exit 2
fi
if (( PORT < 1 || PORT > 65535 )); then
  log_err "port out of range (1-65535): '${PORT}'"
  exit 2
fi

# Configurable timeout seconds (can override via env)
CONNECT_TIMEOUT_S="${CONNECT_TIMEOUT_S:-2}"

# Validate timeout
if ! [[ "${CONNECT_TIMEOUT_S}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  log_err "CONNECT_TIMEOUT_S must be a number, got: '${CONNECT_TIMEOUT_S}'"
  exit 2
fi

# --- ensure prerequisites ---
if ! command -v timeout >/dev/null 2>&1; then
  log_err "'timeout' command not found. Install coreutils: sudo apt-get install -y coreutils"
  exit 2
fi

# date +%s%3N requires GNU date (Ubuntu has it)
if ! date +%s%3N >/dev/null 2>&1; then
  log_err "GNU date with millisecond format (+%s%3N) not supported in this environment."
  exit 2
fi

# If HOST looks like a domain (not IPv4), precheck A record via dig.
# If no A record -> output -1 and exit 0.
if ! is_ipv4 "${HOST}"; then
  if ! command -v dig >/dev/null 2>&1; then
    log_err "'dig' command not found. Install dnsutils: sudo apt-get install -y dnsutils"
    exit 2
  fi

  if ! has_a_record "${HOST}"; then
    printf '%s\n' "-1"
    exit 0
  fi
fi

# --- measure connect time ---
t0="$(date +%s%3N)"

# /dev/tcp triggers connect() inside bash.
# We suppress stderr from the inner bash to keep output clean; failures handled via rc.
timeout "${CONNECT_TIMEOUT_S}" bash -c "exec 3<>/dev/tcp/${HOST}/${PORT}; exec 3>&- 3<&-" 2>/dev/null
rc=$?

t1="$(date +%s%3N)"
ms=$(( t1 - t0 ))

if [[ $rc -eq 0 ]]; then
  printf '%s\n' "${ms}"
  exit 0
fi

if [[ $rc -eq 124 ]]; then
  log_err "connect timeout after ${CONNECT_TIMEOUT_S}s host='${HOST}' port='${PORT}' cost_ms=${ms}"
  exit 3
fi

log_err "connect failed rc=${rc} host='${HOST}' port='${PORT}' cost_ms=${ms}"
exit 3
