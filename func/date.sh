#!/bin/bash
# shellcheck disable=SC1090 disable=SC2028 disable=SC2086
[ -z "$ROOT_URI" ] && source <(curl -sSL https://dev.kubectl.org/init) && export ROOT_URI=$ROOT_URI
source <(curl -sSL "$ROOT_URI/func/log.sh")

# 定义日期格式列表
declare -A date_formats=(
  [date_general]='+%Y-%m-%d %H:%M:%S'
  [datetime_version]='+%Y-%m-%d_%H-%M-%S'
  [datetime_tight_version]='+%Y%m%d%H%M%S'
  [date_version]='+%Y-%m-%d'
  [date_tight_version]='+%Y%m%d'
)

# 循环生成变量并打印
for var in "${!date_formats[@]}"; do
  value=$(date "${date_formats[$var]}")
  # 使用 declare -g 保证在函数外也可访问
  declare -g "$var=$value"
  log_info "version" "$var : $value"
done
