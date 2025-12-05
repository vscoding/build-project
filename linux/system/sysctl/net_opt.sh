#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2155 disable=SC2128 disable=SC2028
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
export ROOT_URI=$ROOT_URI
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)

log_info "optimize" "network"

if [ ! -f "/etc/sysctl.conf" ]; then
  log_error "optimize" "sysctl.conf not found"
  exit
fi

function try_clear() {
  log_info "optimize" "try clear old"
  sed -i '/^# OPTIMIZE NETWORK START$/,/^# OPTIMIZE NETWORK END$/d' /etc/sysctl.conf
}

function write_sysctl_conf() {
  log_info "optimize" "write sysctl conf"
  cat >>/etc/sysctl.conf <<EOF
# OPTIMIZE NETWORK START

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

# Enable fast recycling of TIME-WAIT sockets
net.ipv4.tcp_tw_recycle = 1

# Enable reuse of TIME-WAIT sockets for new connections
net.ipv4.tcp_tw_reuse = 1

# Increase the number of allowed local ports
net.ipv4.ip_local_port_range = 1024 65535

# Enable TCP keepalive
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 5

# OPTIMIZE NETWORK END
EOF
}

try_clear
write_sysctl_conf
