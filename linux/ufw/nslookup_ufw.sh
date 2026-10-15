#!/usr/bin/env bash
# shellcheck disable=SC2164 disable=SC2155 disable=SC2046 disable=SC2086

DOMAIN=$1
DNS_SERVER=$2
IP_CACHE_FILE=$3

shift 3
PORTS=("$@") # 剩余参数：端口列表

# 默认端口：如果没有端口输入，则只开放 443
if [[ ${#PORTS[@]} -eq 0 ]]; then
  PORTS=(443)
fi

# -------------------------------
# 日志函数
# -------------------------------
log() {
  local remark="${1:-unknown remark}"
  local msg="${2:-unknown message}"
  local now
  now=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "$now - [INFO ] [ $remark ] $msg"
}

# -------------------------------
# 工具函数
# -------------------------------
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

validate_ipv4() {
  local ip=$1
  [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

# -------------------------------
# 前置检查
# -------------------------------
prepare() {
  if ! command_exists nslookup; then
    log "check" "nslookup command not found"
    exit 1
  fi
}

# -------------------------------
# 获取域名 IP
# -------------------------------
get_domain_ip() {
  local domain=$1
  local dns_server=$2
  local result ip_line

  result=$(nslookup "$domain" "$dns_server" 2>/dev/null | grep "Address:")

  # 取最后一行 IP
  if [ "$(echo "$result" | wc -l)" -ge 2 ]; then
    ip_line=$(echo "$result" | tail -n 1 | awk '{print $2}')
    echo "$ip_line"
  else
    echo ""
  fi
}

# -------------------------------
# 缓存与 UFW 处理
# -------------------------------
update_ufw() {
  local domain_ip=$1
  local cache_ip=""

  # 读取缓存
  if [[ -f "$IP_CACHE_FILE" ]]; then
    cache_ip=$(<"$IP_CACHE_FILE")
  fi

  # 校验缓存 IP，否则重置
  if ! validate_ipv4 "$cache_ip"; then
    cache_ip=""
  fi

  # UFW 检查
  if ! command_exists /usr/sbin/ufw; then
    log "ufw" "ufw command not found"
    return
  fi

  # ------ 循环处理多端口 ------
  for port in "${PORTS[@]}"; do

    if [[ "$cache_ip" != "$domain_ip" ]]; then

      # 删除旧规则
      if [[ -n "$cache_ip" ]]; then
        local del_output
        del_output=$(/usr/sbin/ufw --force delete allow from "$cache_ip" to any port "$port" 2>&1)
        log "ufw" "delete [$cache_ip:$port]: $del_output"
      fi

      # 添加新规则
      local add_output
      add_output=$(/usr/sbin/ufw allow from "$domain_ip" to any port "$port" 2>&1)
      log "ufw" "allow  [$domain_ip:$port]: $add_output"

    else
      # IP 未变 → 检查规则是否存在，不存在则补齐
      if /usr/sbin/ufw status | grep -q "$domain_ip.*$port"; then
        log "ufw" "already allowed: $domain_ip:$port"
      else
        local add_output
        add_output=$(/usr/sbin/ufw allow from "$domain_ip" to any port "$port" 2>&1)
        log "ufw" "re-allow [$domain_ip:$port]: $add_output"
      fi
    fi

  done

  # 写入最新 IP
  echo "$domain_ip" >"$IP_CACHE_FILE"
}

# -------------------------------
# 主流程
# -------------------------------
main() {
  prepare

  local domain_ip
  domain_ip=$(get_domain_ip "$DOMAIN" "$DNS_SERVER")

  log "dns" "domain=$DOMAIN, ip=$domain_ip, ports=${PORTS[*]}"

  if ! validate_ipv4 "$domain_ip"; then
    log "validate" "invalid domain ip"
    exit 1
  fi

  update_ufw "$domain_ip"
}

main "$@"

# End
