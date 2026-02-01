#!/bin/bash
# shellcheck disable=SC1090,SC2086,SC2155,SC2128,SC2028,SC2164,SC2162
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)
set -Eeuo pipefail
source <(curl -sSL $ROOT_URI/func/log.sh)

C=CN
ST=Shanghai
L=Shanghai
O=devops
OU=devops
# CN...
emailAddress="tech@intellij.io"

# different from the above
CA_CN=${CA_CN:-"DEFAULT_TEST_CA"}

SSL_DIR="ssl"
SUBJECT_PREFIX=""

init() {
  log_info "INIT" "init ssl folder"

  # read ssl dir
  read -p "Enter SSL directory (default: ssl): " input_ssl_dir
  if [ -n "$input_ssl_dir" ]; then
    SSL_DIR="$input_ssl_dir"
  fi

  if [ -f "$SSL_DIR" ]; then
    read -p "'$SSL_DIR' is a file, remove it? (default y) (y/n): " yn
    if [ -z $yn ]; then
      yn="y"
    fi
    case $yn in
      [Yy]*)
        log_info "INIT" "Removing file '$SSL_DIR'"
        rm -rf "$SSL_DIR"
        ;;
      [Nn]*)
        log_info "INIT" "User chose not to remove the file. Exiting."
        exit 1
        ;;
      *)
        log_info "INIT" "Please answer yes or no."
        exit 1
        ;;
    esac
  fi

  if [ -d "$SSL_DIR" ]; then
    read -p "'$SSL_DIR' directory already exists, remove it? (default y) (y/n): " yn
    if [ -z $yn ]; then
      yn="y"
    fi
    case $yn in
      [Yy]*)
        log_info "INIT" "Removing existing directory '$SSL_DIR'"
        rm -rf "$SSL_DIR"
        ;;
      [Nn]*)
        log_info "INIT" "User chose not to remove the existing directory. Exiting."
        exit 1
        ;;
      *)
        log_info "INIT" "Please answer yes or no."
        exit 1
        ;;
    esac
  fi

  mkdir -p "$SSL_DIR"/{client,server}
}

SYSTEM_TYPE=""
detect_system_type() {
  # https://stackoverflow.com/questions/31506158/running-openssl-from-a-bash-script-on-windows-subject-does-not-start-with
  local OS="$(uname -s)"
  case $OS in
    Linux)
      SYSTEM_TYPE="Linux"
      SUBJECT_PREFIX="/"
      ;;
    Darwin)
      SYSTEM_TYPE="Mac"
      SUBJECT_PREFIX="/"
      ;;
    CYGWIN* | MINGW32* | MSYS* | MINGW*)
      SYSTEM_TYPE="Windows"
      SUBJECT_PREFIX="//"
      ;;
    *)
      SYSTEM_TYPE="Unknown"
      ;;
  esac

  if [ "$SYSTEM_TYPE" = "Unknown" ]; then
    log_error "SYSTEM_TYPE" "Unknown system type"
    exit 1
  fi
}

create_key() {
  local target_file=$1
  openssl genrsa -out "$target_file" 2048
}

create_ca() {
  log_info "[CA]" "create ca"

  local CA_KEY_FILE="$SSL_DIR/ca.key"

  log_info "[CA]" "1. Create CA Key: $CA_KEY_FILE"
  create_key "$CA_KEY_FILE"

  log_info "[CA]" "2. Create CA CRT"
  local CA_SUBJ="${SUBJECT_PREFIX}C=${C}\ST=${ST}\L=${L}\O=${O}\OU=${OU}\emailAddress=${emailAddress}\CN=${CA_CN}"
  openssl req -x509 -sha256 -new -nodes -key "$CA_KEY_FILE" -days 3650 -out \
    "$SSL_DIR/ca.crt" \
    -subj "${CA_SUBJ}"

  openssl x509 -in "$SSL_DIR/ca.crt" -text
}

SERVER_CN=${SERVER_CN:-"DEFAULT_TEST_SERVER"}
SERVER_DNS1=$SERVER_CN
SERVER_DNS2="localhost"
SERVER_IP1="127.0.0.1"

create_server() {
  log_info "[Server]" "create server"

  local SERVER_DIR="$SSL_DIR/server"
  local SERVER_KEY_FILE="$SERVER_DIR/server.key"

  log_info "[Server]" "1. Create Server Key: $SERVER_KEY_FILE"
  create_key "$SERVER_KEY_FILE"

  create_server_csr() {
    log_info "[Server]" "2. create server certificate signing request"
    local SERVER_SUBJ="${SUBJECT_PREFIX}C=${C}\ST=${ST}\L=${L}\O=${O}\OU=${OU}\emailAddress=${emailAddress}\CN=${SERVER_CN}"
    openssl req -new -key "$SERVER_KEY_FILE" -sha256 \
      -subj "$SERVER_SUBJ" \
      -out "$SERVER_DIR/server.csr"
  }

  create_server_crt() {
    log_info "[Server]" "3.1 create v3.ext.ini"
    cat >"$SERVER_DIR/v3.ext.ini" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SERVER_DNS1
DNS.2 = $SERVER_DNS2
IP.1 = $SERVER_IP1
EOF

    log_info "[Server]" "3.2 create server certificate"
    openssl x509 -req -sha256 \
      -in "$SERVER_DIR/server.csr" \
      -CA "$SSL_DIR/ca.crt" -CAkey "$SSL_DIR/ca.key" \
      -CAcreateserial \
      -out "$SERVER_DIR/server.crt" \
      -days 3650 \
      -extfile "$SERVER_DIR/v3.ext.ini"
  }

  create_server_csr
  create_server_crt
  # openssl pkcs8 -topk8 -in $server_folder/server.key -out $server_folder/pkcs8_server.key -nocrypt
  openssl x509 -in "$SERVER_DIR/server.crt" -text
}

CLIENT_CN=${CLIENT_CN:-"DEFAULT_TEST_CLIENT"}

create_client() {
  log_info "[Client]" "create client"
  local CLIENT_DIR="$SSL_DIR/client"
  local CLIENT_KEY_FILE="$CLIENT_DIR/client.key"

  log_info "[Client]" "1. Create Client Key: $CLIENT_KEY_FILE"
  create_key "$CLIENT_DIR/client.key"

  create_client_csr() {
    log_info "[Client]" "2. create client certificate signing request"
    local CLIENT_SUBJ="${SUBJECT_PREFIX}C=${C}\ST=${ST}\L=${L}\O=${O}\OU=${OU}\emailAddress=${emailAddress}\CN=${CLIENT_CN}"
    openssl req -new -key "$CLIENT_KEY_FILE" -sha256 \
      -subj "$CLIENT_SUBJ" \
      -out "$CLIENT_DIR/client.csr"
  }

  create_client_crt() {
    log_info "[Client]" "3.1 create v3.ext.ini"
    cat >"$CLIENT_DIR/v3.ext.ini" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $CLIENT_CN
EOF

    log_info "[Client]" "3.2 create client certificate"
    openssl x509 -req -sha256 \
      -in "$CLIENT_DIR/client.csr" \
      -CA "$SSL_DIR/ca.crt" -CAkey "$SSL_DIR/ca.key" \
      -CAcreateserial \
      -out "$CLIENT_DIR/client.crt" \
      -days 3650 \
      -extfile "$CLIENT_DIR/v3.ext.ini"
  }

  create_client_csr
  create_client_crt
  openssl x509 -in "$CLIENT_DIR/client.crt" -text
}

openssl_validate() {
  openssl verify -CAfile "$SSL_DIR/ca.crt" "$SSL_DIR/server/server.crt"
  openssl verify -CAfile "$SSL_DIR/ca.crt" "$SSL_DIR/client/client.crt"
}

init
detect_system_type
create_ca
create_server
create_client
openssl_validate
