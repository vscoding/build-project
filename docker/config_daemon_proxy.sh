#!/bin/bash
# shellcheck disable=SC1090 disable=SC2154 disable=SC2086 disable=SC2028
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/date.sh)

PROXY_URL="$1"
NO_PROXY_CONTENT="$2"

config_path="/etc/systemd/system/docker.service.d/proxy.conf"

[[ -z $PROXY_URL ]] && {
  log_error "validate" "proxy url is blank"
  log_info "proxy url" "e.g. http://127.0.0.1:8888"
  log_info "proxy url" "e.g. socks5h://127.0.0.1:1080"
  exit 1
}

[[ -z $NO_PROXY_CONTENT ]] && {
  NO_PROXY_CONTENT="localhost,127.0.0.1,docker-registry.somecorporation.com"
  log_info "NO_PROXY" "NO_PROXY_CONTENT is blank.default $NO_PROXY_CONTENT"
}

if [ -f $config_path ]; then
  log "backup" "cp $config_path ${config_path}_${datetime_version}"
  cp "$config_path" "${config_path}_${datetime_version}"
fi

function write_to_docker_daemon_proxy_config() {
  log_info "config" "write docker daemon proxy config"
  cat >"$config_path" <<EOF
[Service]
Environment="HTTP_PROXY=$PROXY_URL"
Environment="HTTPS_PROXY=$PROXY_URL"
Environment="NO_PROXY=$NO_PROXY_CONTENT"
EOF
}

mkdir -p "/etc/systemd/system/docker.service.d/" && write_to_docker_daemon_proxy_config
