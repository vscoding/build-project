#!/bin/bash
# shellcheck disable=SC2164,SC1090,SC2086
declare -g config_json="$1"
declare -g test_mode=${2:-false}

if [ -z "$config_json" ]; then
  echo "Usage: ./batch_migrate.sh <config_json> [test_mode]"
  echo "  config_json: Path to the configuration JSON file"
  echo "  test_mode: Optional, set to 'true' to enable test mode (default: false)"
  exit 1
fi

# 如果 test_mode 不是false，则启用测试模式，设置为true
if [[ "$test_mode" != "false" ]]; then
  test_mode="true"
fi

[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
echo -e "\033[0;32mROOT_URI=$ROOT_URI\033[0m"

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/ostype.sh)
source <(curl -sSL $ROOT_URI/func/command_exists.sh)

if is_windows; then
  log_info "build" "build in windows"
  export MSYS_NO_PATHCONV=1
fi

command_exists docker || {
  log_error "prepare" "docker not found, please install docker first"
  exit 1
}

command_exists jq || {
  log_error "prepare" "jq not found, please install jq first"
  exit 1
}

from_image_name=""
tags=()
to_list=()

function show_config_json_tpl() {
  log_info "config_json" "show config template json"
  local tpl_json
  tpl_json=$(curl -sSL $ROOT_URI/docker/tools/config_tpl.json)
  echo "$tpl_json"
}

# 读取配置文件
function read_config_json() {
  if [[ ! -f $config_json ]]; then
    log_error "config_json" "file not found: $config_json"
    exit 1
  fi

  from_image_name=$(jq -r '.from.image_name' "$config_json")
  if [[ -z $from_image_name || "$from_image_name" == "null" ]]; then
    log_error "from.image_name" "not found in $config_json"
    show_config_json_tpl
    exit 1
  fi

  mapfile -t tags < <(jq -r '.from.tags[]' "$config_json" | tr -d '\r')
  if [[ ${#tags[@]} -eq 0 ]]; then
    log_error "from.tags" "not found in $config_json"
    show_config_json_tpl
    exit 1
  fi

  mapfile -t to_list < <(jq -c '.to[]' "$config_json" | tr -d '\r')
  if [[ ${#to_list[@]} -eq 0 ]]; then
    log_error "to list" "not found in $config_json"
    show_config_json_tpl
    exit 1
  fi

  log_info "from_image_name" "$from_image_name"
  log_info "tags" "${tags[*]}"
}

# 执行迁移
function migrate() {
  local tag
  # 遍历 tags
  for tag in "${tags[@]}"; do
    local from="$from_image_name:$tag"

    # 遍历 to_list
    for target in "${to_list[@]}"; do
      local target_name
      local platforms

      target_name=$(jq -r '.image_name' <<<"$target")
      [[ -z $target_name ]] && {
        log_warn "to entry" "skip invalid entry: $target"
        continue
      }

      mapfile -t platforms < <(jq -r '.platforms[]?' <<<"$target" | tr -d '\r')

      # 如果 platforms 为空，默认 linux/amd64
      [[ ${#platforms[@]} -eq 0 ]] && {
        platforms=("linux/amd64")
      }

      [[ -z $target_name || "$target_name" == "null" ]] && {
        log_warn "to entry" "skip invalid entry: $target"
        continue
      }

      local to="$target_name:$tag"

      # 遍历 platforms
      for platform in "${platforms[@]}"; do
        log_info "migrate" "from=$from to=$to platform=$platform"

        if [ "$test_mode" == "true" ]; then
          log_info "test_mode" "skip actual migration in test mode"
        else
          bash <(curl -sSL https://dev.kubectl.net/docker/tools/migrate_p.sh) \
            -s "$from" \
            -t "$to" \
            -p "$platform" \
            -x "re_pull"
        fi
      done
    done
  done
}

function main() {
  log_info "batch_migrate" "start batch migrate from docker hub to other registry"
  read_config_json
  migrate
  log_info "batch_migrate" "batch migrate completed"
}

main "$@"
