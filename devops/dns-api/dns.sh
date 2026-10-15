#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2086,SC2155,SC2128,SC2028,SC2162,SC2034
source <(curl -sSL https://dev.kubectl.net/func/log.sh)

# 检查必要的环境变量
check_required_vars() {
  local missing=0
  for var in "DNSAPI_ROOT_URI" "DNSAPI_ACCESS_TOKEN"; do
    if [ -z "${!var}" ]; then
      log_error "dns" "$var 未设置"
      missing=1
    fi
  done

  if [ $missing -eq 1 ]; then
    exit 1
  fi
}

check_required_vars

# 仅在交互终端启用颜色，避免污染管道或重定向输出
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
  STYLE_RESET=$'\033[0m'
  STYLE_BOLD=$'\033[1m'
  STYLE_CYAN=$'\033[36m'
  STYLE_YELLOW=$'\033[33m'
  STYLE_RED=$'\033[31m'
else
  STYLE_RESET=""
  STYLE_BOLD=""
  STYLE_CYAN=""
  STYLE_YELLOW=""
  STYLE_RED=""
fi

build_prompt() {
  local label=$1
  local default_value=${2:-}

  if [ -n "$default_value" ]; then
    printf '%s›%s %s %s[默认: %s]%s: ' \
      "$STYLE_CYAN" "$STYLE_RESET" "$label" \
      "$STYLE_YELLOW" "$default_value" "$STYLE_RESET"
  else
    printf '%s›%s %s: ' "$STYLE_CYAN" "$STYLE_RESET" "$label"
  fi
}

confirm_action() {
  local message=$1
  local answer

  read -r -p "$(build_prompt "$message [y/N]")" answer
  [[ $answer =~ ^[Yy]$ ]]
}

# 显示操作菜单
show_menu() {
  printf '\n%s%s┌─ DNS 解析管理 ─────────────────────────────┐%s\n' \
    "$STYLE_BOLD" "$STYLE_CYAN" "$STYLE_RESET"
  printf '%s\n' \
    "│   [0] 支持的域名" \
    "│   [1] 新增解析记录" \
    "│   [2] 查询子域名记录"
  printf '%s%s│   [3] 删除子域名的全部记录%s\n' \
    "$STYLE_RED" "$STYLE_BOLD" "$STYLE_RESET"
  printf '%s\n' \
    "│   [4] 设置唯一记录" \
    "│   [5] 分页查询域名记录" \
    "│" \
    "│   [q] 退出"
  printf '%s%s└─────────────────────────────────────────────┘%s\n\n' \
    "$STYLE_CYAN" "$STYLE_BOLD" "$STYLE_RESET"

  read -r -p "$(build_prompt "请选择操作" "q")" dns_operate
}

show_menu

# 调用DNS API
# 参数: $1-域名 $2-主机记录 $3-记录类型 $4-记录值 $5-请求URL
#       $6-页码 $7-每页数量 $8-主机记录关键字 $9-记录值关键字
function dnsapi() {
  local domainName=$1
  local rr=$2
  local type=$3
  local value=$4
  local request_url=$5
  local pageNumber=$6
  local pageSize=$7
  local rrKeyWord=$8
  local valueKeyWord=$9

  local api_root_uri="$DNSAPI_ROOT_URI"
  local access_token_value="$DNSAPI_ACCESS_TOKEN"
  # local json_data='{"domainName":"'$domainName'","rr":"'$rr'","type":"'$type'","value":"'$value'", "pageNumber":"'$pageNumber'", "pageSize":"'$pageSize'", "rrKeyWord":"'$rrKeyWord'", "valueKeyWord":"'$valueKeyWord'"}'
  local json_data=$(jq -n \
    --arg domainName "$domainName" \
    --arg rr "$rr" \
    --arg type "$type" \
    --arg value "$value" \
    --arg pageNumber "$pageNumber" \
    --arg pageSize "$pageSize" \
    --arg rrKeyWord "$rrKeyWord" \
    --arg valueKeyWord "$valueKeyWord" \
    '{domainName:$domainName, rr:$rr, type:$type, value:$value, pageNumber:(if $pageNumber=="" then null else ($pageNumber|tonumber) end), pageSize:(if $pageSize=="" then null else ($pageSize|tonumber) end), rrKeyWord:$rrKeyWord, valueKeyWord:$valueKeyWord}')

  result=$(curl -sSL --connect-timeout 3 -X POST $api_root_uri$request_url \
    --header "Authorization: Bearer $access_token_value" \
    --header 'Content-Type: application/json' \
    --data "$json_data")
}

# 输出 API 响应：成功时突出数据，失败时保留完整响应便于排查
function print_api_response() {
  local action=$1
  local code

  if ! printf '%s\n' "$result" | jq -e . >/dev/null 2>&1; then
    log_error "dns" "$action 失败：API 返回的不是有效 JSON"
    printf '%s\n' "$result"
    return 1
  fi

  code=$(printf '%s\n' "$result" | jq -r '.code // empty')
  if [ -n "$code" ] && [ "$code" != "200" ]; then
    log_error "dns" "$action 失败（code=$code）"
    printf '%s\n' "$result" | jq
    return
  fi

  log_success "dns" "$action 完成"
  printf '%s\n' "$result" | jq 'if type == "object" and has("data") then .data else . end'
}

# 读取用户输入函数，增加输入验证
function readDomainName() {
  if [ -n "$domainName" ]; then
    return
  fi

  while [ -z "$domainName" ]; do
    read -r -p "$(build_prompt "域名")" domainName
    [ -n "$domainName" ] && break
    log_error "dns" "域名不能为空"
  done
}

function readRr() {
  if [ -n "$rr" ]; then
    return
  fi

  while [ -z "$rr" ]; do
    read -r -p "$(build_prompt "主机记录 (Resource Record)")" rr
    [ -n "$rr" ] && break
    log_error "dns" "主机记录不能为空"
  done
}

function readType() {
  read -r -p "$(build_prompt "记录类型" "A")" type

  if [ -z "$type" ]; then
    type="A"
  fi
}

function readValue() {
  while [ -z "$value" ]; do
    read -r -p "$(build_prompt "记录值")" value
    [ -n "$value" ] && break
    log_error "dns" "记录值不能为空"
  done
}

function readPageNumber() {
  while true; do
    read -r -p "$(build_prompt "页码" "1")" pageNumber
    pageNumber=${pageNumber:-1}
    [[ $pageNumber =~ ^[0-9]+$ ]] && return
    log_error "dns" "页码必须为数字"
  done
}

function readPageSize() {
  while true; do
    read -r -p "$(build_prompt "每页数量" "20")" pageSize
    pageSize=${pageSize:-20}
    [[ $pageSize =~ ^[0-9]+$ ]] && return
    log_error "dns" "每页数量必须为数字"
  done
}

function readRrKeyWord() {
  read -r -p "$(build_prompt "主机记录 (RR) 关键字，可留空")" rrKeyWord
}

function readValueKeyWord() {
  read -r -p "$(build_prompt "记录值 (value) 关键字，可留空")" valueKeyWord
}

function quit() {
  while true; do
    read -r -p "$(build_prompt "按 Enter 或 q 退出")" q
    case "$q" in
      q | Q | "")
        log_warn "dns" "退出分页查询域名的解析记录"
        exit 0
        ;;
      *) log_warn "dns" "无效的输入，请重新选择" ;;
    esac
  done
}

# 获取支持的域名列表
function acl() {
  log_info "dns" "获取支持的域名列表"
  dnsapi "" "" "" "" "/acl"
  print_api_response "获取支持的域名列表"
}

# 检查域名是否在支持列表中
function acl_contains() {
  local inputDomain=$1
  dnsapi "" "" "" "" "/acl"

  local contains=$(echo "$result" | jq --raw-output --arg input "$inputDomain" '.data[] | select(contains($input))')

  if [ -z "$contains" ]; then
    log_error "acl" "不支持域名 $inputDomain"
    exit 1 # 添加错误码
  fi
}

# 新增解析记录
function addRecord() {
  readDomainName
  acl_contains $domainName
  readRr
  readType
  readValue
  log_info "dns" "新增解析记录：domain=$domainName rr=$rr type=$type value=$value"
  dnsapi $domainName $rr $type $value "/addRecord"
  print_api_response "新增解析记录"
}

# 查询子域名的所有解析记录
function getRecords() {
  readDomainName
  acl_contains $domainName
  readRr
  log_info "dns" "查询解析记录：domain=$domainName rr=$rr"
  dnsapi $domainName $rr "" "" "/getRecords"
  print_api_response "查询解析记录"
}

# 删除子域名的所有解析记录
function deleteRecords() {
  delete_records_cancelled=0
  readDomainName
  acl_contains $domainName
  readRr

  printf '\n%s%s⚠ 删除确认%s\n' "$STYLE_BOLD" "$STYLE_RED" "$STYLE_RESET"
  printf '  域名：%s\n' "$domainName"
  printf '  主机记录：%s\n\n' "$rr"

  if ! confirm_action "确认删除以上主机记录的全部解析"; then
    delete_records_cancelled=1
    log_warn "dns" "已取消删除操作"
    return
  fi

  log_warn "dns" "删除解析记录：domain=$domainName rr=$rr"
  dnsapi $domainName $rr "" "" "/deleteRecords"
  print_api_response "删除解析记录"
}

# 设置唯一解析记录
function setSingleRecord() {
  readDomainName
  acl_contains "$domainName"
  readRr
  readType
  readValue
  log_info "dns" "设置唯一记录：domain=$domainName rr=$rr type=$type value=$value"
  dnsapi "$domainName" "$rr" "$type" "$value" "/setSingleRecord"
  print_api_response "设置唯一记录"
}

# 分页查询域名解析记录
# 参数：$1-页码 $2-每页数量 $3-主机记录关键字 $4-记录值关键字
function getDomainRecords() {
  local pageNum=$1
  local pageSz=$2
  local rrKw=$3
  local valueKw=$4

  log_info "dns" "查询域名解析记录：domain=$domainName page=$pageNum pageSize=$pageSz"
  dnsapi $domainName "" "" "" "/getDomainRecords" $pageNum $pageSz $rrKw $valueKw

  local code=$(printf '%s\n' "$result" | jq -r '.code // empty')

  function clearAndList() {
    local totalCount=$(printf '%s\n' "$result" | jq -r '.totalCount // 0')
    local currentPage=$(printf '%s\n' "$result" | jq -r '.pageNumber // 1')
    local totalPage=$(printf '%s\n' "$result" | jq -r '.totalPage // 1')

    [ -t 1 ] && clear
    log_success "dns" "查询完成：第 $currentPage/$totalPage 页，共 $totalCount 条记录"

    {
      printf 'TYPE\tNAME\tVALUE\tTTL\tSTATUS\n'
      printf '%s\n' "$result" | jq -r '
        .data[]? |
        [
          .type,
          (if .rr == "@" then .domainName else (.rr + "." + .domainName) end),
          .value,
          .ttl,
          .status
        ] | @tsv
      '
    } | if command -v column >/dev/null 2>&1; then
      column -t -s $'\t'
    else
      sed 's/\t/ | /g'
    fi
  }

  if [ "$code" == "200" ] || [ "$code" == "" ]; then
    clearAndList $pageNum $pageSz
    local rtPageNumber=$(printf '%s\n' "$result" | jq -r '.pageNumber // 1')
    local totalPage=$(printf '%s\n' "$result" | jq -r '.totalPage // 1')

    if [ $totalPage -le 1 ]; then
      quit
    fi

    while true; do
      read -r -p "$(build_prompt "[P] 上一页  [N/Enter] 下一页  [Q] 退出")" pn
      case "$pn" in
        q | Q)
          log_warn "dns" "退出分页查询域名的解析记录"
          exit 0
          ;;
        n | N | "")
          if [ $rtPageNumber -ge $totalPage ]; then
            getDomainRecords 1 $pageSz $rrKw $valueKw
          else
            getDomainRecords $((rtPageNumber + 1)) $pageSz $rrKw $valueKw
          fi
          ;;
        p | P)
          if [ $rtPageNumber -eq 1 ]; then
            getDomainRecords $totalPage $pageSz $rrKw $valueKw
          else
            getDomainRecords $((rtPageNumber - 1)) $pageSz $rrKw $valueKw
          fi
          ;;
        *)
          log_warn "dns" "无效的输入，请重新选择"
          ;;
      esac
    done
  else
    log_error "dns" "分页查询域名的解析记录失败"
    printf '%s\n' "$result" | jq
  fi
}

# 主程序处理逻辑
case $dns_operate in
  0)
    acl
    ;;
  1)
    addRecord
    ;;
  2)
    getRecords
    ;;
  3)
    deleteRecords
    ;;
  4)
    setSingleRecord
    ;;
  5)
    readDomainName
    readPageNumber
    readPageSize
    readRrKeyWord
    readValueKeyWord
    getDomainRecords $pageNumber $pageSize $rrKeyWord $valueKeyWord
    ;;
  q | Q | "")
    log_info "dns" "没有选择任何操作，退出"
    ;;
  *) log_warn "dns" "无效的操作：$dns_operate" ;;
esac
