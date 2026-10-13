#!/bin/bash
# shellcheck disable=SC1090
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)
export ROOT_URI

source <(curl -sSL "$ROOT_URI/func/log.sh")

source <(curl -sSL $ROOT_URI/func/ostype.sh)

if is_windows; then
  log_info "build" "build in windows"
  export MSYS_NO_PATHCONV=1
fi

set -e

if ! command -v openssl >/dev/null 2>&1; then
  log_error "build" "openssl not found, please install openssl first"
  exit 1
fi

OUT_DIR="${1:-${OUT_DIR:-$(pwd)}}"
DAYS="${DAYS:-825}"
CERT_CN="${CERT_CN:-localhost}"
CERT_SAN_DNS="${CERT_SAN_DNS:-localhost}"
CERT_SAN_IP="${CERT_SAN_IP:-}"
CERT_FILENAME="${CERT_FILENAME:-fullchain.cer}"
KEY_FILENAME="${KEY_FILENAME:-private.key}"

KEY_CHOICE=""
while true; do
  printf '%s\n' \
    "Select key type:" \
    "  1) ecdsa:256 (default)" \
    "  2) rsa:2048" \
    "  3) rsa:4096"
  read -r -p "Enter choice [1]: " KEY_CHOICE
  case "${KEY_CHOICE:-1}" in
    1)
      NEWKEY_ALGORITHM="ec"
      KEYGEN_OPTIONS=(-pkeyopt ec_paramgen_curve:P-256)
      KEY_TYPE="ecdsa:256"
      KEY_USAGE="digitalSignature"
      break
      ;;
    2)
      NEWKEY_ALGORITHM="rsa:2048"
      KEYGEN_OPTIONS=()
      KEY_TYPE="rsa:2048"
      KEY_USAGE="digitalSignature, keyEncipherment"
      break
      ;;
    3)
      NEWKEY_ALGORITHM="rsa:4096"
      KEYGEN_OPTIONS=()
      KEY_TYPE="rsa:4096"
      KEY_USAGE="digitalSignature, keyEncipherment"
      break
      ;;
    *)
      log_warn "build" "invalid key type selection: $KEY_CHOICE"
      ;;
  esac
done

if ! mkdir -p -- "$OUT_DIR"; then
  log_error "build" "failed to create output directory: $OUT_DIR"
  exit 1
fi

CERT_FILE="$OUT_DIR/$CERT_FILENAME"
KEY_FILE="$OUT_DIR/$KEY_FILENAME"

OPENSSL_CERT_FILE="$CERT_FILE"
OPENSSL_KEY_FILE="$KEY_FILE"

SAN_DNS_ARRAY=("$CERT_CN")
IFS=',' read -r -a EXTRA_SAN_DNS_ARRAY <<<"$CERT_SAN_DNS"

for dns_name in "${EXTRA_SAN_DNS_ARRAY[@]}"; do
  dns_name="${dns_name// /}"
  [ -n "$dns_name" ] || continue

  san_exists=0
  for existing_dns_name in "${SAN_DNS_ARRAY[@]}"; do
    if [ "$existing_dns_name" = "$dns_name" ]; then
      san_exists=1
      break
    fi
  done

  if [ "$san_exists" -eq 0 ]; then
    SAN_DNS_ARRAY+=("$dns_name")
  fi
done

SAN_ENTRIES=""
for san_index in "${!SAN_DNS_ARRAY[@]}"; do
  SAN_ENTRIES+="DNS.$((san_index + 1)) = ${SAN_DNS_ARRAY[$san_index]}\n"
done

SAN_IP_ARRAY=()
IFS=',' read -r -a EXTRA_SAN_IP_ARRAY <<<"$CERT_SAN_IP"

for ip_address in "${EXTRA_SAN_IP_ARRAY[@]}"; do
  ip_address="${ip_address// /}"
  [ -n "$ip_address" ] || continue

  san_exists=0
  for existing_ip_address in "${SAN_IP_ARRAY[@]}"; do
    if [ "$existing_ip_address" = "$ip_address" ]; then
      san_exists=1
      break
    fi
  done

  if [ "$san_exists" -eq 0 ]; then
    SAN_IP_ARRAY+=("$ip_address")
  fi
done

for san_index in "${!SAN_IP_ARRAY[@]}"; do
  SAN_ENTRIES+="IP.$((san_index + 1)) = ${SAN_IP_ARRAY[$san_index]}\n"
done

RESOLVED_SAN_DNS=$(
  IFS=,
  printf '%s' "${SAN_DNS_ARRAY[*]}"
)
RESOLVED_SAN_IP=$(
  IFS=,
  printf '%s' "${SAN_IP_ARRAY[*]}"
)

OPENSSL_CNF_FILE="$(mktemp "${OUT_DIR%/}/openssl-fallback-XXXXXX.cnf")"
trap 'rm -f "$OPENSSL_CNF_FILE"' EXIT

OPENSSL_CNF_ARG="$OPENSSL_CNF_FILE"

if is_windows && command -v cygpath >/dev/null 2>&1; then
  OPENSSL_CNF_ARG="$(cygpath -w "$OPENSSL_CNF_FILE")"
  OPENSSL_CERT_FILE="$(cygpath -w "$CERT_FILE")"
  OPENSSL_KEY_FILE="$(cygpath -w "$KEY_FILE")"
fi

log_info "build" "generating test certificate"
log_info "build" \
  "parameters: cn=$CERT_CN san=$RESOLVED_SAN_DNS san_ip=$RESOLVED_SAN_IP days=$DAYS key_type=$KEY_TYPE"
log_info "build" \
  "output files: certificate=$CERT_FILE private_key=$KEY_FILE"

cat >"$OPENSSL_CNF_FILE" <<EOF
[req]
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
CN = ${CERT_CN}

[v3_req]
basicConstraints = CA:FALSE
keyUsage = ${KEY_USAGE}
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
$(printf "%b" "$SAN_ENTRIES")
EOF

openssl req \
  -x509 \
  -nodes \
  -newkey "$NEWKEY_ALGORITHM" \
  "${KEYGEN_OPTIONS[@]}" \
  -keyout "$OPENSSL_KEY_FILE" \
  -out "$OPENSSL_CERT_FILE" \
  -days "$DAYS" \
  -config "$OPENSSL_CNF_ARG" \
  -extensions v3_req

chmod 600 "$KEY_FILE" 2>/dev/null || true

cert_size=$(wc -c <"$CERT_FILE" 2>/dev/null || printf 'unknown')
key_size=$(wc -c <"$KEY_FILE" 2>/dev/null || printf 'unknown')
cert_size="${cert_size//[[:space:]]/}"
key_size="${key_size//[[:space:]]/}"

log_info "build" \
  "test certificate generated: path=$CERT_FILE bytes=$cert_size"
log_info "build" \
  "test private key generated: path=$KEY_FILE bytes=$key_size permissions=600"

cert_details=$(openssl x509 \
  -in "$OPENSSL_CERT_FILE" \
  -noout \
  -fingerprint \
  -sha256 \
  -startdate \
  -enddate 2>/dev/null || true)

if [ -n "$cert_details" ]; then
  while IFS= read -r cert_detail; do
    log_info "build" "certificate detail: $cert_detail"
  done <<<"$cert_details"
else
  log_warn "build" "certificate details are unavailable"
fi

log_info "build" \
  "test certificate generation completed: cn=$CERT_CN san=$RESOLVED_SAN_DNS san_ip=$RESOLVED_SAN_IP"
