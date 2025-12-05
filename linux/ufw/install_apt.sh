#!/bin/bash
# shellcheck disable=SC1090 disable=SC2034 disable=SC2086 disable=SC2028

[ -z "$ROOT_URI" ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

log_info "ufw" "config ufw"

# -------------------------------
# Detect SSH port
# -------------------------------
detect_ssh_port() {
  ssh_port=$(bash <(curl -sSL "$ROOT_URI/func/ssh_port.sh"))
  log_info "ssh_port" "ssh port is $ssh_port"
}

# -------------------------------
# Install UFW
# -------------------------------
install_ufw() {
  log_info "ufw" "install ufw"
  apt-get update -y && apt-get install -y ufw
}

# -------------------------------
# Config UFW
# -------------------------------
config_ufw() {
  log_info "ufw_config" "set IPV6=no"
  if [[ -f "/etc/default/ufw" ]]; then
    sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
  fi
}

# -------------------------------
# Enable UFW
# -------------------------------
enable_ufw() {
  log_info "ufw" "enable ufw"
  systemctl enable ufw
  ufw --force enable
  ufw status verbose
}

# -------------------------------
# Allow Rules
# -------------------------------
ufw_allow_ssh() {
  log_info "ufw" "allow ssh on port $ssh_port"
  ufw allow "$ssh_port"
  ufw reload
  ufw status verbose
}

ufw_allow_web() {
  log_info "ufw" "allow http/https"
  ufw allow 80
  ufw allow 443
  ufw reload
  ufw status verbose
}

# -------------------------------
# Tips
# -------------------------------
tips() {
  log_info "tips" "install strategy:"
  log_info "tips" "  oi   = only install (do not config)"
  log_info "tips" "  oics = install, config ssh & web"
  log_info "tips" "e.g.: bash <(curl -sSL $ROOT_URI/linux/ufw/install_apt.sh) oi"
  log_info "tips" "e.g.: bash <(curl -sSL $ROOT_URI/linux/ufw/install_apt.sh) oics"
}

# -------------------------------
# Main
# -------------------------------
main() {
  local strategy=$1
  detect_ssh_port

  if command_exists ufw; then
    log_info "ufw" "ufw is already installed"
  else
    log_info "ufw" "ufw is NOT installed"
    [[ "$strategy" =~ ^(oi|oics)$ ]] && install_ufw
  fi

  case "$strategy" in
    oics)
      enable_ufw
      config_ufw
      ufw_allow_ssh
      ufw_allow_web
      ;;
    oi)
      log_info "ufw" "only installed, no config"
      ;;
    *)
      tips
      ;;
  esac
}

main "$1"
