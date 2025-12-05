#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2028

[ -z "$ROOT_URI" ] && source <(curl -sSL https://dev.kubectl.org/init) && export ROOT_URI=$ROOT_URI

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

# -----------------------------
# 日期变量和日志
# -----------------------------
declare -A version_list=(
  [date_general]='+%Y-%m-%d %H:%M:%S'
  [datetime_version]='+%Y-%m-%d_%H-%M-%S'
  [datetime_tight_version]='+%Y%m%d%H%M%S'
  [date_version]='+%Y-%m-%d'
  [date_tight_version]='+%Y%m%d'
)

for var in "${!version_list[@]}"; do
  value=$(date "${version_list[$var]}")
  declare -g "$var=$value"
  log_info "date" "$var=$value"
done

# -----------------------------
# Git 版本信息
# -----------------------------
if command_exists git; then
  if git log --oneline >/dev/null 2>&1; then
    log_info "git" "git log --abbrev-commit --pretty=oneline -n 1"
    git_version=$(git log --abbrev-commit --pretty=oneline -n 1 | head -c 7)
    declare -g git_version
    log_info "git" "git_version=$git_version"
  else
    log_warn "git" "No commit record"
  fi
fi
