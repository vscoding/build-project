#!/bin/bash
# ====== 颜色定义 ======
NC='\033[0m'              # reset
TS_COLOR='\033[0;36m'     # 时间青色
REMARK_COLOR='\033[0;36m' # remark 青色

# ====== 内部日志函数 ======
_log() {
  local level="$1" color="$2" remark="$3" msg="$4"
  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S")

  local level_str="${color}[${level^^}]${NC}"
  local remark_str=""
  [[ -n "$remark" ]] && remark_str="${REMARK_COLOR}[ ${remark} ]${NC} "

  if [[ -n "$remark" && -n "$msg" ]]; then
    # 两者都有，正常显示
    echo -e "${TS_COLOR}${ts}${NC} - ${level_str} ${remark_str}${msg}"
  elif [[ -n "$msg" ]]; then
    # 只有 msg
    echo -e "${TS_COLOR}${ts}${NC} - ${level_str} ${msg}"
  elif [[ -n "$remark" ]]; then
    # 只有 remark，将其作为主要内容显示（不带方括号修饰，或者保留修饰）
    echo -e "${TS_COLOR}${ts}${NC} - ${level_str} ${remark}"
  else
    # 两者都无
    echo -e "${TS_COLOR}${ts}${NC} - ${level_str}"
  fi
}

# ====== 日志函数 ======
log_debug() { _log "DEBUG" "\033[0;36m" "$@"; }    # 青色
log() { _log "INFO " "\033[0;34m" "$@"; }          # 蓝色
log_info() { _log "INFO " "\033[0;34m" "$@"; }     # 蓝色
log_success() { _log "OK   " "\033[0;32m" "$@"; }  # 绿色
log_warn() { _log "WARN " "\033[38;5;208m" "$@"; } # 橙色
log_error() { _log "ERROR" "\033[0;31m" "$@"; }    # 红色
log_fatal() { _log "FATAL" "\033[1;41;97m" "$@"; } # 白字红底
log_notice() { _log "NOTE " "\033[0;35m" "$@"; }   # 紫色
log_trace() { _log "TRACE" "\033[0;90m" "$@"; }    # 灰色

# log 作为 info 别名
declare -f log >/dev/null 2>&1 || log() { log_info "$@"; }

# ====== 分隔行 ======
line_break() { echo; }
