#!/bin/bash
# shellcheck disable=SC1090 disable=SC2154 disable=SC2086 disable=SC2028
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/date.sh)

log_info "bashrc" "config bashrc proxy"

PROXY_URL="$1"
NO_PROXY_CONTENT="$2"

if [ -z $PROXY_URL ]; then
  log_error "validate" "proxy url is blank"
  log_info "proxy url" "e.g. http://127.0.0.1:8888"
  log_info "proxy url" "e.g. socks5h://127.0.0.1:1080"
  exit 1
fi

if [ -z $NO_PROXY_CONTENT ]; then
  NO_PROXY_CONTENT=".local,localhost,127.0.0.1,192.168.*.*,10.0.0.0/8"
  log_info "NO_PROXY" "NO_PROXY_CONTENT is blank.default $NO_PROXY_CONTENT"
fi

file="$HOME/.bashrc"

if [ -f $file ]; then
  log_warn "bashrc" "try delete"
  sed -i '/^# BASHRC PROXY CONFIG START$/,/^# BASHRC PROXY CONFIG END$/d' $file
fi

function config_bashrc_proxy_config() {
  log "bashrc" "append bashrc"
  cat <<EOF >>$file
# BASHRC PROXY CONFIG START
export HTTP_PROXY=$PROXY_URL
export HTTPS_PROXY=$PROXY_URL

export NO_PROXY=$NO_PROXY_CONTENT

# BASHRC PROXY CONFIG END
EOF
}

config_bashrc_proxy_config

systemctl daemon-reload
