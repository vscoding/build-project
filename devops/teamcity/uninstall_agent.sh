#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2155 disable=SC2128 disable=SC2028  disable=SC2317  disable=SC2164 disable=SC2004 disable=SC2154
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/devops/teamcity/commons.sh)

log_info "teamcity" "uninstall agent or agents"

remove_systemd
