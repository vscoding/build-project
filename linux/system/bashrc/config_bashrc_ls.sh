#!/bin/bash
# shellcheck disable=SC1090
set -euo pipefail

if [[ -z "${ROOT_URI:-}" ]]; then
  source <(curl -fsSL "https://dev.kubectl.org/init")
fi
export ROOT_URI="${ROOT_URI:-}"

source <(curl -fsSL "${ROOT_URI}/func/log.sh")
source <(curl -fsSL "${ROOT_URI}/func/detect_os.sh")

log_info "bashrc" "config bashrc ls"

BASHRC_FILE="${HOME}/.bashrc"
BLOCK_START="# BASHRC CONFIG LS START"
BLOCK_END="# BASHRC CONFIG LS END"

clear_old_bashrc_config() {
  if [[ ! -f "${BASHRC_FILE}" ]]; then
    touch "${BASHRC_FILE}"
    return
  fi

  log_info "bashrc" "clear old ls config"
  sed -i "/^${BLOCK_START}$/,/^${BLOCK_END}$/d" "${BASHRC_FILE}"
}

append_bashrc_config() {
  log_info "bashrc" "append ls config"
  cat >>"${BASHRC_FILE}" <<EOF
# BASHRC CONFIG LS START

# You may uncomment the following lines if you want \`ls' to be colorized:
# export LS_OPTIONS='--color=auto'
# eval "\$(dircolors)"

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "\$(dircolors -b ~/.dircolors)" || eval "\$(dircolors -b)"
  alias ls='ls --color=auto'
  #alias dir='dir --color=auto'
  #alias vdir='vdir --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

alias lla='ls -ahlF --group-directories-first -X'
alias ll='ls -hlF --group-directories-first -X'
alias la='ls -A --group-directories-first -X'
alias l='ls -CF --group-directories-first -X'
#
# Some more alias to avoid making mistakes:
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# tabby
export PS1="\$PS1\[\e]1337;CurrentDir="'\$(pwd)\a\]'

TMOUT=0
# BASHRC CONFIG LS END

EOF
}

unsupported_os_todo() {
  log_warn "bashrc" "TODO ..."
}

case "${os_base_name:-}" in
  Ubuntu | Debian)
    clear_old_bashrc_config
    append_bashrc_config
    ;;
  *)
    unsupported_os_todo
    ;;
esac
