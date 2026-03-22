#!/bin/bash
# shellcheck disable=SC1090
set -euo pipefail

if [[ -z "${ROOT_URI:-}" ]]; then
  source <(curl -fsSL "https://dev.kubectl.org/init")
fi
export ROOT_URI="${ROOT_URI:-}"
echo -e "\033[0;32mROOT_URI=${ROOT_URI}\033[0m"

source <(curl -fsSL "${ROOT_URI}/func/log.sh")
source <(curl -fsSL "${ROOT_URI}/func/ostype.sh")

if is_windows; then
  log_info "optimize" "windows not support"
  exit 0
fi

SYSCTL_CONF="/etc/sysctl.conf"
BBR_START="# BBR START"
BBR_END="# BBR END"

if [[ ! -f "${SYSCTL_CONF}" ]]; then
  log_error "optimize" "sysctl.conf not found"
  exit 1
fi

clear_old_bbr_config() {
  log_info "optimize" "clear old bbr config"
  sed -i "/^${BBR_START}$/,/^${BBR_END}$/d" "${SYSCTL_CONF}"
}

write_bbr_config() {
  log_info "optimize" "write bbr config"
  cat >>"${SYSCTL_CONF}" <<EOF
${BBR_START}
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_slow_start_after_idle=0
${BBR_END}
EOF
}

log_info "optimize" "bbr"
clear_old_bbr_config
write_bbr_config
