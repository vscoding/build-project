#!/bin/bash
# shellcheck disable=SC1090
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)
source <(curl -sSL "$ROOT_URI/func/log.sh")

# Required: CP_HOST, CP_CERT_TOKEN, CP_CERT_KEY
# Optional: DOWNLOAD_DIR, CERT_FILENAME, PRIVATE_KEY_FILENAME
cp_host_value="${CP_HOST:-}"
declare -r CP_HOST="${cp_host_value%/}"
declare -r CP_TOKEN="${CP_CERT_TOKEN:-}"
declare -r CP_CERT_KEY="${CP_CERT_KEY:-}"
declare -r DOWNLOAD_DIR="${DOWNLOAD_DIR:-${CP_CERT_KEY:-cp-cert}}"
declare -r CERT_FILENAME="${CERT_FILENAME:-fullchain.pem}"
declare -r PRIVATE_KEY_FILENAME="${PRIVATE_KEY_FILENAME:-private.key}"
unset cp_host_value

declare -r metadata_uri="/api/acme-client/certificate/metadata"
declare -r fullchain_uri="/api/acme-client/certificate/fullchain.cer"
declare -r private_key_uri="/api/acme-client/certificate/private.key"

download_dir="${DOWNLOAD_DIR%/}"
[ -z "$download_dir" ] && download_dir="/"

declare -r metadata_file="${download_dir}/.metadata.json"
declare -r cert_file="${download_dir}/${CERT_FILENAME}"
declare -r private_key_file="${download_dir}/${PRIVATE_KEY_FILENAME}"

metadata_tmp=""
metadata_pretty_tmp=""
cert_tmp=""
private_key_tmp=""

cleanup() {
  [ -n "$metadata_tmp" ] && rm -f -- "$metadata_tmp"
  [ -n "$metadata_pretty_tmp" ] && rm -f -- "$metadata_pretty_tmp"
  [ -n "$cert_tmp" ] && rm -f -- "$cert_tmp"
  [ -n "$private_key_tmp" ] && rm -f -- "$private_key_tmp"
}

fail() {
  log_error "acme-cp" "$1"
  exit 1
}

download() {
  local name="$1"
  local uri="$2"
  local output_file="$3"
  local http_code
  local curl_code

  http_code=$(curl --silent --show-error --location \
    --output "$output_file" \
    --write-out "%{http_code}" \
    --get \
    --data-urlencode "key=$CP_CERT_KEY" \
    --header "Authorization: Bearer $CP_TOKEN" \
    "${CP_HOST}${uri}")
  curl_code=$?

  if [ "$curl_code" -ne 0 ]; then
    log_error "acme-cp" "download failed: name=$name curl_code=$curl_code"
    return 1
  fi

  if [ "$http_code" != "200" ]; then
    log_error "acme-cp" "download failed: name=$name http_code=$http_code"
    return 1
  fi

  if [ ! -s "$output_file" ]; then
    log_error "acme-cp" "download failed: name=$name response body is empty"
    return 1
  fi

  log_info "acme-cp" "downloaded: name=$name http_code=$http_code"
}

trap cleanup EXIT

command -v curl >/dev/null 2>&1 ||
  fail "curl is required but not installed"
command -v jq >/dev/null 2>&1 ||
  fail "jq is required but not installed"

[ -n "$CP_HOST" ] ||
  fail "CP_HOST is required"
case "$CP_HOST" in
  http://* | https://*) ;;
  *) fail "CP_HOST must start with http:// or https://" ;;
esac

[ -n "$CP_TOKEN" ] ||
  fail "CP_CERT_TOKEN is required"
[ -n "$CP_CERT_KEY" ] ||
  fail "CP_CERT_KEY is required"
[ -n "${DOWNLOAD_DIR//\//}" ] ||
  fail "DOWNLOAD_DIR cannot be /"
[ -n "$CERT_FILENAME" ] ||
  fail "CERT_FILENAME cannot be empty"
[ -n "$PRIVATE_KEY_FILENAME" ] ||
  fail "PRIVATE_KEY_FILENAME cannot be empty"
case "$CERT_FILENAME" in
  */* | *\\* | "." | ".." | "metadata.json")
    fail "CERT_FILENAME must be a filename and cannot be metadata.json"
    ;;
esac
case "$PRIVATE_KEY_FILENAME" in
  */* | *\\* | "." | ".." | "metadata.json")
    fail "PRIVATE_KEY_FILENAME must be a filename and cannot be metadata.json"
    ;;
esac
[ "$CERT_FILENAME" != "$PRIVATE_KEY_FILENAME" ] ||
  fail "CERT_FILENAME and PRIVATE_KEY_FILENAME must be different"

if ! mkdir -p -- "$download_dir"; then
  fail "failed to create download directory: $download_dir"
fi

metadata_tmp=$(mktemp "${download_dir}/.metadata.XXXXXX") ||
  fail "failed to create metadata temporary file"

download "metadata" "$metadata_uri" "$metadata_tmp" ||
  fail "metadata is unavailable: key=$CP_CERT_KEY"

if ! jq -e '
  .code == 200
  and .data.available == true
  and (.data.fingerprintSha256 | type == "string" and length > 0)
' "$metadata_tmp" >/dev/null 2>&1; then
  fail "invalid metadata response: code, available or fingerprintSha256 is invalid"
fi

metadata_pretty_tmp=$(mktemp "${download_dir}/.metadata-pretty.XXXXXX") ||
  fail "failed to create formatted metadata temporary file"
if ! jq '.data' "$metadata_tmp" >"$metadata_pretty_tmp"; then
  fail "failed to extract metadata data"
fi
if ! mv -f -- "$metadata_pretty_tmp" "$metadata_tmp"; then
  fail "failed to replace metadata with formatted content"
fi
metadata_pretty_tmp=""

remote_fingerprint=$(jq -r '.fingerprintSha256' "$metadata_tmp")
local_fingerprint=""
if [ -s "$metadata_file" ]; then
  local_fingerprint=$(jq -r '.fingerprintSha256 // empty' \
    "$metadata_file" 2>/dev/null)
fi

if [ "$remote_fingerprint" = "$local_fingerprint" ] &&
  [ -s "$cert_file" ] &&
  [ -s "$private_key_file" ]; then
  log_info "acme-cp" \
    "certificate is unchanged: key=$CP_CERT_KEY fingerprintSha256=$remote_fingerprint"
  exit 0
fi

if [ "$remote_fingerprint" = "$local_fingerprint" ]; then
  log_warn "acme-cp" \
    "certificate file or private key file is missing, downloading again"
elif [ -n "$local_fingerprint" ]; then
  log_info "acme-cp" \
    "new certificate found: old=$local_fingerprint new=$remote_fingerprint"
else
  log_info "acme-cp" \
    "certificate found: fingerprintSha256=$remote_fingerprint"
fi

cert_tmp=$(mktemp "${download_dir}/.certificate.XXXXXX") ||
  fail "failed to create certificate temporary file"
private_key_tmp=$(mktemp "${download_dir}/.private-key.XXXXXX") ||
  fail "failed to create private key temporary file"

download "certificate" "$fullchain_uri" "$cert_tmp" ||
  fail "failed to download certificate: key=$CP_CERT_KEY"
download "private-key" "$private_key_uri" "$private_key_tmp" ||
  fail "failed to download private key: key=$CP_CERT_KEY"

grep -q -- "-----BEGIN CERTIFICATE-----" "$cert_tmp" ||
  fail "invalid certificate content"
grep -Eq -- "-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY-----" "$private_key_tmp" ||
  fail "invalid private key content"

chmod 644 "$cert_tmp" "$metadata_tmp" 2>/dev/null ||
  log_warn "acme-cp" "failed to set certificate or metadata permissions"
chmod 600 "$private_key_tmp" 2>/dev/null ||
  log_warn "acme-cp" "failed to set private key permissions"

if ! mv -f -- "$cert_tmp" "$cert_file"; then
  fail "failed to save certificate: $cert_file"
fi
cert_tmp=""

if ! mv -f -- "$private_key_tmp" "$private_key_file"; then
  fail "failed to save private key: $private_key_file"
fi
private_key_tmp=""

if ! mv -f -- "$metadata_tmp" "$metadata_file"; then
  fail "failed to save metadata: $metadata_file"
fi
metadata_tmp=""

log_info "acme-cp" \
  "certificate downloaded: key=$CP_CERT_KEY fingerprintSha256=$remote_fingerprint dir=$download_dir"
