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
readonly docker_config_dir="$HOME/.docker"
readonly docker_config_path="$docker_config_dir/config.json"
# $'...' 是 Bash 的 ANSI-C quoting 语法
readonly docker_ps_format=$'table {{.ID}}\t{{.Image}}\t{{.RunningFor}}\t{{.Status}}\t{{.Names}}'

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

function write_to_docker_client_config() {
  local tmp_config_path="${docker_config_path}.tmp"

  if ! command -v jq >/dev/null 2>&1; then
    log_error "config" "jq command not found, cannot update $docker_config_path"
    exit 1
  fi

  if [[ ! -s "$docker_config_path" ]]; then
    printf '{}\n' >"$docker_config_path"
  fi

  if ! jq --arg ps_format "$docker_ps_format" '.psFormat = $ps_format' "$docker_config_path" >"$tmp_config_path"; then
    rm -f "$tmp_config_path"
    log_error "config" "failed to update $docker_config_path"
    exit 1
  fi

  if ! mv "$tmp_config_path" "$docker_config_path"; then
    log_error "config" "failed to replace $docker_config_path"
    exit 1
  fi

  log_info "config" "update $docker_config_path psFormat"
}

log_info "config" "config $docker_config_path"
if [[ ! -d "$docker_config_dir" ]]; then
  log_warn "config" "create directory $docker_config_dir"
  mkdir -p "$docker_config_dir"
fi

if [[ ! -f "$docker_config_path" ]]; then
  log_warn "config" "create file $docker_config_path"
fi

write_to_docker_client_config
