#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2028
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)

now=$(date +"%Y-%m-%d_%H-%M-%S")

log "create folder" "try create m2 folder"
mkdir -p "$HOME/.m2"

function backup_settings() {
  if [ -f "$HOME/.m2/settings.xml" ]; then
    log "backup" "from settings.xml to settings_$now.xml"
    mv "$HOME/.m2/settings.xml" "$HOME/.m2/settings_$now.xml"
  fi
}

backup_settings

function download_settings() {
  curl -sSL $ROOT_URI/maven/settings.xml -o "$HOME/.m2/settings.xml"
  log "show settings" "ls -l $HOME/.m2/"
  ls -l "$HOME/.m2/"
}

download_settings
