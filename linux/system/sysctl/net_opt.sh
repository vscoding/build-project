#!/usr/bin/env bash
# shellcheck disable=SC1090
set -euo pipefail

if [[ -z "${ROOT_URI:-}" ]]; then
  source <(curl -fsSL "https://dev.kubectl.org/init")
fi
export ROOT_URI="${ROOT_URI:-}"

source <(curl -fsSL "${ROOT_URI}/func/log.sh")

SYSCTL_CONF="/etc/sysctl.conf"
BLOCK_START="# OPTIMIZE NETWORK START"
BLOCK_END="# OPTIMIZE NETWORK END"

log_info "optimize" "network"

if [[ ! -f "${SYSCTL_CONF}" ]]; then
  log_error "optimize" "sysctl.conf not found"
  exit 1
fi

validate_network_config() {
  if ! awk -v start="${BLOCK_START}" -v end="${BLOCK_END}" '
    $0 == start {
      if (in_block) {
        invalid = 1
      }
      in_block = 1
      next
    }
    $0 == end {
      if (!in_block) {
        invalid = 1
      }
      in_block = 0
    }
    END {
      exit invalid || in_block
    }
  ' "${SYSCTL_CONF}"; then
    log_error "optimize" "invalid network config markers"
    return 1
  fi
}

clear_old_network_config() {
  log_info "optimize" "clear old network config"
  validate_network_config || return 1
  sed -i "/^${BLOCK_START}$/,/^${BLOCK_END}$/d" "${SYSCTL_CONF}"
}

write_network_config() {
  log_info "optimize" "write network config"
  cat >>"${SYSCTL_CONF}" <<EOF
${BLOCK_START}

# Enable ip forward
net.ipv4.ip_forward = 1

# Increase the size of the receive buffer
net.core.rmem_max = 16777216

# Increase the size of the send buffer
net.core.wmem_max = 16777216

# Increase the maximum number of packets allowed to queue
net.core.netdev_max_backlog = 5000

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1

# Increase the TCP read buffer space
net.ipv4.tcp_rmem = 4096 87380 16777216

# Increase the TCP write buffer space
net.ipv4.tcp_wmem = 4096 65536 16777216

# Enable TCP SYN cookies
net.ipv4.tcp_syncookies = 1

# Enable TCP keepalive
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 5

${BLOCK_END}
EOF
}

clear_old_network_config
write_network_config
