#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2155 disable=SC2128 disable=SC2028 disable=SC2164
SHELL_FOLDER=$(cd "$(dirname "$0")" && pwd) && cd "$SHELL_FOLDER"
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
export ROOT_URI=$ROOT_URI
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)

if [ -f "$HOME/.ssh" ]; then
  log_error "prepare" "$HOME/.ssh is a file, not a directory"
  exit
fi

if [ ! -d "$HOME/.ssh" ]; then
  log_warn "prepare" "$HOME/.ssh not found, create it"
  mkdir -p "$HOME/.ssh"
fi

ssh_ed25519="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIODf32spVGqhfv1mKRU17TiI8pGVdZzK+W24OsZTS0Nu tech@intellij.io"
ecdsa_sha2_nistp521="ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGuoPeUH3nQVxZ+HMj4h4uHHuQclc7BnxUVxVm1wFfk/rYalMZxNkbG5MfNt0i8J/vs8G6BMqzTyCNp97SvrhTB9ADdCX53cMSdVKumUbHrLzJX14DRWz7gUmCqMW0DbWhbWzAR63Xv2Zc4E0fnuiA/j31AWppFf80aBFI4O0xV9MX9Pw== tech@intellij.io"

keys=$HOME/.ssh/authorized_keys
if [ ! -f "keys" ]; then
  log_warn "prepare" "keys not found, create it"
  touch "$keys"
fi

# check if the keys already exist
if grep -q "$ssh_ed25519" "$keys"; then
  log_info "prepare" "ssh_ed25519 already exists"
else
  echo "$ssh_ed25519" >>"$keys"
  log_info "add" "ssh_ed25519 added"
fi

if grep -q "$ecdsa_sha2_nistp521" "$keys"; then
  log_info "prepare" "ecdsa_sha2_nistp521 already exists"
else
  echo "$ecdsa_sha2_nistp521" >>"$keys"
  log_info "add" "ecdsa_sha2_nistp521 added"
fi
