#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)

bash <(curl -sSL $ROOT_URI/docker/install/install_apt_tpl.sh) \
  "debian" \
  "https://mirrors.iproute.org/container/docker-ce"
