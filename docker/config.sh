#!/bin/bash
# shellcheck disable=SC1090 disable=SC2154 disable=SC2086 disable=SC2028
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/date.sh)

registry=$1
data_root=$2
bip=$3
default_address_pools_base=$4

[[ -z $registry ]] && registry="https://docker.mirrors.ustc.edu.cn"
[[ -z "$data_root" ]] && data_root="/var/lib/docker"
[[ -z "$bip" ]] && bip="172.10.0.1/16"
[[ -z "$default_address_pools_base" ]] && default_address_pools_base="172.11.0.0/16"

log_info "config" "docker registry: $registry"
log_info "config" "docker data root: $data_root"
log_info "config" "docker bip: $bip"
log_info "config" "docker default address pools base: $default_address_pools_base"

readonly config_path="/etc/docker/daemon.json"

[[ -f "$config_path" ]] && {
  log "backup" "cp $config_path ${config_path}_${datetime_version}"
  cp "$config_path" "${config_path}_${datetime_version}"
}

function write_to_daemon_json() {
  log "config" "write docker config"
  cat >"$config_path" <<EOF
{
  "insecure-registries": [],
  "registry-mirrors": [
    "$registry"
  ],
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ],
  "bip": "$bip",
  "default-address-pools": [
    {
      "base": "$default_address_pools_base",
      "size": 24
    }
  ],
  "data-root": "$data_root",
  "log-opts": {
    "max-file": "5",
    "max-size": "20m"
  }
}
EOF
}

mkdir -p "/etc/docker/" && write_to_daemon_json
