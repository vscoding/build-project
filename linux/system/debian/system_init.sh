#!/bin/bash
# shellcheck disable=SC2164 disable=SC2086 disable=SC1090
source <(curl -sSL https://dev.kubectl.org/init)
export ROOT_URI=$ROOT_URI

source <(curl -sSL $ROOT_URI/func/log.sh)

log_info "update" "apt-get update & upgrade"

bash <(curl -sSL $ROOT_URI/linux/system/update.sh)

log_info "init" "init bashrc ls"

bash <(curl -sSL $ROOT_URI/linux/system/bashrc/config_bashrc_ls.sh)

log_info "init" "remove snap"

bash <(curl -sSL $ROOT_URI/linux/system/ubuntu/rm_snap.sh)
