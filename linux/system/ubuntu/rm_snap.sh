#!/bin/bash
# shellcheck disable=SC2164 disable=SC2086 disable=SC1090
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
export ROOT_URI=$ROOT_URI

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/command_exists.sh)

if ! command_exists snap; then
  log_info "prepare" "command snap does not exist"
  exit
fi

function remove_snap() {

  function remove_snap_software() {
    for i in {1..3}; do
      log_info "remove_snap_software" "times $i"
      for p in $(snap list | awk '{print $1}'); do
        sudo snap remove $p
      done
    done
  }

  function remove_snap_core() {
    sudo systemctl stop snapd
    sudo systemctl disable --now snapd.socket
    for m in /snap/core/*; do
      sudo umount $m
    done
  }

  function remove_snap_apt() {
    sudo apt-get autoremove -y --purge snapd
  }

  function clear_snap_directory() {
    rm -rf ~/snap
    sudo rm -rf /snap
    sudo rm -rf /var/snap
    sudo rm -rf /var/lib/snapd
    sudo rm -rf /var/cache/snapd
  }

  function reject_apt_install() {
    sudo sh -c "cat > /etc/apt/preferences.d/no-snapd.pref" <<EOF
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
  }

  function validate() {
    apt-get install snapd -y
  }

  remove_snap_software
  remove_snap_core
  remove_snap_apt
  clear_snap_directory
  reject_apt_install
  validate
}

remove_snap
