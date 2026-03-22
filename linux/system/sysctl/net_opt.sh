#!/bin/bash
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

clear_old_network_config() {
  log_info "optimize" "clear old network config"
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
net.core.rmem_default = 16777216

# Increase the size of the send buffer
net.core.wmem_max = 16777216
net.core.wmem_default = 16777216

# Increase the maximum number of packets allowed to queue
net.core.netdev_max_backlog = 5000

# Increase the maximum number of connections
net.core.somaxconn = 1024

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1

# Increase the TCP read buffer space
net.ipv4.tcp_rmem = 4096 87380 16777216

# Increase the TCP write buffer space
net.ipv4.tcp_wmem = 4096 65536 16777216

# Increase the maximum number of open files
fs.file-max = 100000

# Enable TCP SYN cookies
net.ipv4.tcp_syncookies = 1

# Enable reuse of TIME-WAIT sockets for new connections
net.ipv4.tcp_tw_reuse = 1

# Increase the number of allowed local ports
net.ipv4.ip_local_port_range = 1024 65535

# Enable TCP keepalive
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 5

${BLOCK_END}
EOF
}

clear_old_network_config
write_network_config
