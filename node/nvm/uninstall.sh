#!/bin/bash
# shellcheck disable=SC2164 disable=SC2086 disable=SC1090
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL $ROOT_URI/func/log.sh)

function delete_npmrc() {
  log_warn "delete" "rm -rf $HOME/.npmrc"
  rm -rf $HOME/.npmrc
}

function delete_nvm() {
  log_warn "delete" "rm -rf $HOME/.nvm"
  rm -rf $HOME/.nvm
}

function delete_bashrc_content() {
  log_warn "delete" "sed"
  sed -i '/^# NVM CONFIG START$/,/^# NVM CONFIG END$/d' $HOME/.bashrc
}

delete_npmrc
delete_nvm
delete_bashrc_content
