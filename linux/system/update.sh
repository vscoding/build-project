#!/bin/bash
# shellcheck disable=SC1090 disable=SC2154  disable=SC2086 disable=SC2028
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
export ROOT_URI=$ROOT_URI
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/detect_os.sh)

log "update" "update system & prepare"

function apt_upgrade() {
  apt-get update -y
  # WARNING: apt does not have a stable CLI interface. Use with caution in scripts
  #  DEBCONF_NONINTERACTIVE_SEEN=true \
  echo '* libraries/restart-without-asking boolean true' | debconf-set-selections

  #  DEBIAN_FRONTEND=noninteractive：设置包管理器在非交互模式下运行，从而避免在安装或升级软件包时弹出交互式对话框。
  #  DEBCONF_NONINTERACTIVE_SEEN=true：确保所有的 debconf 配置项都已经标记为“Seen”（已处理），使其不会在后续的操作中再提示。

  #  NEEDRESTART_MODE=a
  # a: 自动重启所有需要重启的服务。
  # i: 显示交互提示，询问用户是否需要重启服务（默认行为）
  # l: 只列出需要重启的服务，不实际执行重启。
  # m: 像 i 一样，但在没有终端可用时使用自动方式。
  # n: 不重启任何服务。
  export DEBIAN_FRONTEND=noninteractive
  export DEBCONF_NONINTERACTIVE_SEEN=true
  export NEEDRESTART_MODE=a
  apt-get upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" --allow-downgrades --allow-remove-essential --allow-change-held-packages

  apt-get install -y sudo vim git wget net-tools jq lsof tree zip unzip
}

function other_update_todo() {
  #  yum update -y
  log_info "other" "todo ..."
}

if [ "$os_base_name" == "Ubuntu" ] || [ "$os_base_name" == "Debian" ]; then
  apt_upgrade
else
  other_update_todo
fi
