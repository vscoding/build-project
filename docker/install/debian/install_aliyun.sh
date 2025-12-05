#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

bash <(curl -sSL $ROOT_URI/docker/install/install_apt_tpl.sh) \
  "debian" \
  "https://mirrors.aliyun.com/docker-ce"
