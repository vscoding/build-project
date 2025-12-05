#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2155
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL $ROOT_URI/func/log.sh)
bash <(curl -sSL $ROOT_URI/docker/install/uninstall_apt.sh)

function install_docker() {
  local os="$1"
  local source="$2"

  log_info "show" "os is $1|mirror is $source"

  function add_gpg_key() {
    log_info "install" "add gpg key & repo ..."
    # Add Docker's official GPG key:
    sudo apt-get update -y
    sudo apt-get install ca-certificates curl -y
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "$source/linux/$os/gpg" -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] $source/linux/$os \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    log_info "install" "add gpg key & repo ...done"
    sudo apt-get update -y
    log_info "install" "apt-get update ...done"
  }

  function apt_install_docker() {
    log_info "install" "install docker ..."
    local packages=(
      "docker-ce"
      "docker-ce-cli"
      "containerd.io"
      "docker-buildx-plugin"
      "docker-compose-plugin"
    )
    local pkg_string=$(
      IFS=" "
      echo "${packages[*]}"
    )
    sudo apt-get install -y $pkg_string
  }

  add_gpg_key
  apt_install_docker

}
# os source
install_docker "$1" "$2"
