#!/bin/bash
# shellcheck disable=SC2164,SC1090,SC2086
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init) &&
  export ROOT_URI=$ROOT_URI
echo -e "\033[0;32mROOT_URI=$ROOT_URI\033[0m"

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/ostype.sh)

if is_windows; then
  log_error "validate" "Windows is not supported for docker-compose installation."
  exit 1
fi

# 获取linux的架构
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
  log_info "validate" "Detected architecture: x86_64"
elif [ "$ARCH" == "aarch64" ]; then
  log_info "validate" "Detected architecture: aarch64"
else
  log_error "validate" "Unsupported architecture: $ARCH"
  exit 1
fi

DOCKER_COMPOSE_VERSION="v5.1.3"
DOCKER_COMPOSE_DOWNLOAD_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${ARCH}"
TARGET_FILE='/usr/local/bin/docker-compose'

MIRROR_URL="https://mirrors.iproute.org/proxy_pass"
POST_DATA="{\"src\":\"${DOCKER_COMPOSE_DOWNLOAD_URL}\"}"
CURL_COMMAND="curl -fsSL -X POST \"${MIRROR_URL}\" -H \"Content-Type: application/json\" -d '${POST_DATA}' -o \"${TARGET_FILE}\""

log_info "download" "url=${DOCKER_COMPOSE_DOWNLOAD_URL}"
log_info "download" "target=${TARGET_FILE}"
log_info "download" "${CURL_COMMAND}"

if ! curl -fsSL -X POST "${MIRROR_URL}" \
  -H "Content-Type: application/json" \
  -d "${POST_DATA}" \
  -o "${TARGET_FILE}"; then
  log_error "download" "Failed to download docker-compose"
  exit 1
fi

if ! chmod +x "${TARGET_FILE}"; then
  log_error "install" "Failed to chmod +x ${TARGET_FILE}"
  exit 1
fi
log_success "install" "docker-compose installed: ${TARGET_FILE}"

# docker-compose version
if ! docker-compose version; then
  log_error "validate" "Failed to verify docker-compose installation"
  exit 1
fi

log_success "validate" "docker-compose installation verified successfully"
