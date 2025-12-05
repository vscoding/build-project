#!/bin/bash
# shellcheck disable=SC1090
[ -z "$ROOT_URI" ] && source <(curl -sSL https://dev.kubectl.org/init)
bash <(curl -sSL "$ROOT_URI/docker/install/i.sh") "$1"
