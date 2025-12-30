#!/bin/bash
# shellcheck disable=SC2164,SC2155,SC2046,SC2086

# ============================================================
# Usage:
#   bash dig_ufw.sh <domain> <dns_server> <cache_file> [port1 port2 ...]
#
# Example:
#   bash dig_ufw.sh example.com 8.8.8.8 /tmp/example.ip 443 8443
# ============================================================

DOMAIN=$1
DNS_SERVER=$2
IP_CACHE_FILE=$3

shift 3
PORTS=("$@")

# 默认端口
if [[ ${#PORTS[@]} -eq 0 ]]; then
  PORTS=(443)
fi

# ------------------------------------------------------------
# 日志
# ------------------------------------------------------------
log() {
  local remark="${1:-unknown}"
  local msg="${2:-}"
  local now
  now=$(date +"%Y-%m-%d %H:%M:%S")
  echo "$now - [INFO ] [$remark] $msg"
}

# ------------------------------------------------------------
# 工具函数
# ------------------------------------------------------------
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

validate_ipv4() {
  local ip=$1
  [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

# ------------------------------------------------------------
# 前置检查
# ------------------------------------------------------------
prepare() {
  if ! command_exists dig; then
    log "check" "dig command not found"
    exit 1
  fi

  if ! command_exists /usr/sbin/ufw; then
    log "check" "ufw command not found"
    exit 1
  fi
}

# ------------------------------------------------------------
# 获取域名的所有 A 记录
# ------------------------------------------------------------
get_domain_ips() {
  local domain=$1
  local dns_server=$2

  if [[ -n "$dns_server" ]]; then
    dig @"$dns_server" "$domain" A +short
  else
    dig "$domain" A +short
  fi
}

# ------------------------------------------------------------
# 读取缓存 IP 集合
# ------------------------------------------------------------
read_cached_ips() {
  if [[ -f "$IP_CACHE_FILE" ]]; then
    grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' "$IP_CACHE_FILE"
  fi
}

# ------------------------------------------------------------
# 计算集合差异
# ------------------------------------------------------------
diff_ips() {
  local new_ips="$1"
  local old_ips="$2"

  IPS_TO_ADD=$(comm -13 <(echo "$old_ips" | sort) <(echo "$new_ips" | sort))
  IPS_TO_DEL=$(comm -23 <(echo "$old_ips" | sort) <(echo "$new_ips" | sort))
}

# ------------------------------------------------------------
# 同步 UFW 规则
# ------------------------------------------------------------
update_ufw() {
  local new_ips="$1"
  local old_ips="$2"

  diff_ips "$new_ips" "$old_ips"

  for port in "${PORTS[@]}"; do

    # 删除已失效 IP
    for ip in $IPS_TO_DEL; do
      local out
      out=$(/usr/sbin/ufw --force delete allow from "$ip" to any port "$port" 2>&1)
      log "ufw" "delete [$ip:$port]: $out"
    done

    # 添加新 IP
    for ip in $IPS_TO_ADD; do
      local out
      out=$(/usr/sbin/ufw allow from "$ip" to any port "$port" 2>&1)
      log "ufw" "allow  [$ip:$port]: $out"
    done

  done

  # 更新缓存
  echo "$new_ips" | sort -u >"$IP_CACHE_FILE"
}

# ------------------------------------------------------------
# 主流程
# ------------------------------------------------------------
main() {
  prepare

  local new_ips old_ips

  new_ips=$(get_domain_ips "$DOMAIN" "$DNS_SERVER" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$')
  old_ips=$(read_cached_ips)

  log "dns" "domain=$DOMAIN, ports=${PORTS[*]}"
  log "dns" "resolved_ips: $(echo "$new_ips" | tr '\n' ' ')"

  if [[ -z "$new_ips" ]]; then
    log "validate" "no A records resolved"
    exit 1
  fi

  update_ufw "$new_ips" "$old_ips"
}

main "$@"

# End
