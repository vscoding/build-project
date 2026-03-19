#!/bin/bash
# shellcheck disable=SC1090 disable=SC2154 disable=SC2086 disable=SC2028
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
export ROOT_URI=$ROOT_URI
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/detect_os.sh)

log "update" "update system & prepare"

function apt_upgrade() {
  # Debian/Ubuntu flow: refresh index -> non-interactive upgrade -> install common tools.
  apt-get update -y
  # WARNING: apt does not have a stable CLI interface. Use with caution in scripts.
  # DEBCONF_NONINTERACTIVE_SEEN=true \
  echo '* libraries/restart-without-asking boolean true' | debconf-set-selections

  # DEBIAN_FRONTEND=noninteractive: avoid interactive prompts during package operations.
  # DEBCONF_NONINTERACTIVE_SEEN=true: mark debconf questions as seen to suppress re-prompts.
  # NEEDRESTART_MODE options:
  # a: automatically restart services that need restart.
  # i: interactive mode (default behavior).
  # l: list services that need restart without restarting.
  # m: interactive, fallback to automatic mode without a TTY.
  # n: do not restart any services.
  export DEBIAN_FRONTEND=noninteractive
  export DEBCONF_NONINTERACTIVE_SEEN=true
  export NEEDRESTART_MODE=a
  apt-get upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" --allow-downgrades --allow-remove-essential --allow-change-held-packages

  apt-get install -y sudo vim git wget net-tools jq lsof tree zip unzip
}

function yum_upgrade() {
  # RHEL/CentOS flow: refresh cache -> upgrade system -> install common tools.
  yum makecache -y
  yum update -y
  yum install -y sudo vim git wget net-tools jq lsof tree zip unzip
}

function other_update_todo() {
  # Unsupported non-apt/yum distributions are intentionally left as TODO.
  log_info "other" "todo ..."
}

if [ "$os_base_name" == "Ubuntu" ] || [ "$os_base_name" == "Debian" ]; then
  apt_upgrade
elif command -v yum >/dev/null 2>&1; then
  yum_upgrade
else
  other_update_todo
fi
