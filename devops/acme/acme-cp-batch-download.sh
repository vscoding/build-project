#!/bin/bash
# shellcheck disable=SC1090
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)
export ROOT_URI

source <(curl -sSL "$ROOT_URI/func/log.sh")

declare -r CONFIG_FILE="${1:-${ACME_CP_CONFIG_FILE:-acme-cp-batch-download-config.json}}"
declare -r ACME_CP_SCRIPT_URI="${ROOT_URI%/}/devops/acme/acme-cp.sh"

fail() {
  log_error "acme-cp-batch-download" "$1"
  exit 1
}

command -v curl >/dev/null 2>&1 ||
  fail "curl is required but not installed"
command -v jq >/dev/null 2>&1 ||
  fail "jq is required but not installed"

[ -f "$CONFIG_FILE" ] ||
  fail "config file not found: $CONFIG_FILE"
[ -r "$CONFIG_FILE" ] ||
  fail "config file is not readable: $CONFIG_FILE"

if ! jq -e '
  type == "object"
  and (.cp_host | type == "string" and length > 0)
  and (.configs | type == "array" and length > 0)
  and all(.configs[];
    type == "object"
    and (.cp_cert_key | type == "string" and length > 0)
    and (.cp_cert_token | type == "string" and length > 0)
    and ((has("download_dir") | not) or (.download_dir | type == "string"))
    and ((has("cert_filename") | not) or (.cert_filename | type == "string"))
    and (
      (has("private_key_filename") | not)
      or (.private_key_filename | type == "string")
    )
  )
' -- "$CONFIG_FILE" >/dev/null 2>&1; then
  fail "invalid config: cp_host and non-empty configs are required"
fi

cp_host=$(jq -r '.cp_host' -- "$CONFIG_FILE")

acme_cp_script=$(curl --fail --silent --show-error --location \
  "$ACME_CP_SCRIPT_URI") ||
  fail "failed to download acme-cp.sh: $ACME_CP_SCRIPT_URI"
[ -n "$acme_cp_script" ] ||
  fail "downloaded acme-cp.sh is empty: $ACME_CP_SCRIPT_URI"

total=0
success=0
failed=0

while IFS= read -r config; do
  total=$((total + 1))

  cp_cert_key=$(jq -r '.cp_cert_key' <<<"$config")
  cp_cert_token=$(jq -r '.cp_cert_token' <<<"$config")
  download_dir=$(jq -r '.download_dir // empty' <<<"$config")
  cert_filename=$(jq -r '.cert_filename // empty' <<<"$config")
  private_key_filename=$(jq -r '.private_key_filename // empty' <<<"$config")

  log_info "acme-cp-batch-download" \
    "downloading certificate: key=$cp_cert_key"

  if CP_HOST="$cp_host" \
    CP_CERT_KEY="$cp_cert_key" \
    CP_CERT_TOKEN="$cp_cert_token" \
    DOWNLOAD_DIR="$download_dir" \
    CERT_FILENAME="$cert_filename" \
    PRIVATE_KEY_FILENAME="$private_key_filename" \
    bash <(printf '%s\n' "$acme_cp_script"); then
    success=$((success + 1))
    log_info "acme-cp-batch-download" \
      "certificate processed: key=$cp_cert_key"
  else
    failed=$((failed + 1))
    log_error "acme-cp-batch-download" \
      "certificate failed: key=$cp_cert_key"
  fi
done < <(jq -c '.configs[]' -- "$CONFIG_FILE")

log_info "acme-cp-batch-download" \
  "batch completed: total=$total success=$success failed=$failed"

[ "$failed" -eq 0 ] || exit 1
