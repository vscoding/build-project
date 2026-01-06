#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------
# 日志开关：
#   DEBUG=1  -> 打印日志
#   未设置   -> 静默
# ------------------------------------------------------------
DEBUG="${DEBUG:-}"

log() {
  if [[ -n "$DEBUG" ]]; then
    local level="$1"
    shift
    echo "[$level] $*" >&2
  fi
}

get_last_http_status() {
  # 取最后一个 HTTP/x.y 状态码（解决 proxy CONNECT 问题）
  awk '/^HTTP\/[0-9.]+/ {code=$2} END {print code}'
}

extract_digest() {
  # HTTP header 大小写不敏感
  awk -F': ' 'tolower($1)=="docker-content-digest" {print $2}' | tr -d '\r'
}

get_image_digest() {
  local registry="$1"
  local repo="$2"
  local tag="$3"
  local http_proxy="${4:-}"

  log INFO "registry=${registry} repo=${repo} tag=${tag}"

  local curl_opts=(
    -s
    -D -
    -o /dev/null
    -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.docker.distribution.manifest.v2+json"
  )

  if [[ -n "$http_proxy" ]]; then
    log INFO "using http_proxy=${http_proxy}"
    curl_opts+=(--proxy "$http_proxy")
  fi

  local manifest_url="https://${registry}/v2/${repo}/manifests/${tag}"
  log DEBUG "manifest_url=${manifest_url}"

  # ------------------------------------------------------------
  # 1. 匿名请求
  # ------------------------------------------------------------
  log INFO "try anonymous request"
  local resp
  resp=$(curl "${curl_opts[@]}" "$manifest_url")

  local status
  status=$(echo "$resp" | get_last_http_status)
  log DEBUG "http_status=${status}"

  if [[ "$status" == "200" ]]; then
    local digest
    digest=$(echo "$resp" | extract_digest)

    if [[ -n "$digest" ]]; then
      log INFO "anonymous access ok"
      log INFO "digest=${digest}"
      echo "$digest"
    else
      log WARN "anonymous access ok but digest missing"
      echo "sha256:"
    fi
    return 0
  fi

  # ------------------------------------------------------------
  # 2. 非 401：直接认为不存在 / 不可访问
  # ------------------------------------------------------------
  if [[ "$status" != "401" ]]; then
    log WARN "unexpected http status ${status}, treat as not found"
    echo "sha256:"
    return 0
  fi

  # ------------------------------------------------------------
  # 3. 解析 WWW-Authenticate
  # ------------------------------------------------------------
  log INFO "anonymous denied, entering bearer token flow"

  local auth_header
  auth_header=$(echo "$resp" | awk -F': ' 'tolower($1)=="www-authenticate" {print $2}')

  if [[ -z "$auth_header" ]]; then
    log WARN "401 but no WWW-Authenticate header"
    echo "sha256:"
    return 0
  fi

  log DEBUG "www-authenticate=${auth_header}"

  local realm service scope
  realm=$(echo "$auth_header" | sed -n 's/.*realm="\([^"]*\)".*/\1/p')
  service=$(echo "$auth_header" | sed -n 's/.*service="\([^"]*\)".*/\1/p')
  scope=$(echo "$auth_header" | sed -n 's/.*scope="\([^"]*\)".*/\1/p')

  if [[ -z "$realm" || -z "$service" || -z "$scope" ]]; then
    log WARN "failed to parse WWW-Authenticate parameters"
    echo "sha256:"
    return 0
  fi

  log INFO "auth realm=${realm}"
  log INFO "auth service=${service}"
  log INFO "auth scope=${scope}"

  # ------------------------------------------------------------
  # 4. 获取 Bearer Token
  # ------------------------------------------------------------
  local token_url="${realm}?service=${service}&scope=${scope}"
  log INFO "fetching bearer token"
  log DEBUG "token_url=${token_url}"

  local token_resp
  token_resp=$(curl -s ${http_proxy:+--proxy "$http_proxy"} "$token_url")

  local token
  token=$(echo "$token_resp" \
    | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

  if [[ -z "$token" ]]; then
    log WARN "token fetch failed"
    echo "sha256:"
    return 0
  fi

  log INFO "token acquired"

  # ------------------------------------------------------------
  # 5. 带 token 再请求 manifest
  # ------------------------------------------------------------
  log INFO "retry manifest request with token"

  resp=$(curl "${curl_opts[@]}" \
    -H "Authorization: Bearer ${token}" \
    "$manifest_url")

  status=$(echo "$resp" | get_last_http_status)
  log DEBUG "http_status=${status}"

  if [[ "$status" != "200" ]]; then
    log WARN "authenticated request failed, status=${status}"
    echo "sha256:"
    return 0
  fi

  local digest
  digest=$(echo "$resp" | extract_digest)

  if [[ -n "$digest" ]]; then
    log INFO "authenticated access ok"
    log INFO "digest=${digest}"
    echo "$digest"
  else
    log WARN "authenticated access ok but digest missing"
    echo "sha256:"
  fi
}

# ------------------------------------------------------------
# CLI 入口
# ------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [[ $# -lt 3 ]]; then
    echo "Usage: ./get_image_digest.sh <registry> <repo> <tag> [http_proxy]" >&2
    exit 1
  fi

  get_image_digest "$@"
fi
