#!/bin/bash
# shellcheck disable=SC2164,SC1090,SC2086
declare -g config_json=""
declare -g test_mode="false"
declare -g remove_after_migrate="${REMOVE_AFTER_MIGRATE:-false}"

function usage() {
  echo "Usage: ./batch_migrate.sh -f <config_json> [-t <true|false>] [-r <true|false>]"
  echo "  -f: Path to the configuration JSON file"
  echo "  -t: Optional, enable or disable test mode (default: false)"
  echo "  -r: Optional, remove local images after migration (overrides REMOVE_AFTER_MIGRATE)"
  echo "  REMOVE_AFTER_MIGRATE: Optional environment variable, true or false (default: false)"
}

while getopts ":f:t:r:" opt; do
  case "$opt" in
    f)
      config_json="$OPTARG"
      ;;
    t)
      case "$OPTARG" in
        true | false)
          test_mode="$OPTARG"
          ;;
        *)
          echo "Invalid value for -t: $OPTARG (expected true or false)" >&2
          usage >&2
          exit 1
          ;;
      esac
      ;;
    r)
      case "$OPTARG" in
        true | false)
          remove_after_migrate="$OPTARG"
          ;;
        *)
          echo "Invalid value for -r: $OPTARG (expected true or false)" >&2
          usage >&2
          exit 1
          ;;
      esac
      ;;
    :)
      echo "Option -$OPTARG requires a value" >&2
      usage >&2
      exit 1
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      usage >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

case "$remove_after_migrate" in
  true | false)
    ;;
  *)
    echo "Invalid value for REMOVE_AFTER_MIGRATE: $remove_after_migrate (expected true or false)" >&2
    usage >&2
    exit 1
    ;;
esac

if [[ $# -ne 0 ]]; then
  echo "Unexpected positional arguments: $*" >&2
  usage >&2
  exit 1
fi

if [[ -z "$config_json" ]]; then
  echo "Option -f is required" >&2
  usage >&2
  exit 1
fi

[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
echo -e "\033[0;32mROOT_URI=$ROOT_URI\033[0m"

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/ostype.sh)
source <(curl -sSL $ROOT_URI/func/command_exists.sh)
source <(curl -sSL $ROOT_URI/docker/tools/compare_image.sh)

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
    local -a migrated_images=("$from")

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
      migrated_images+=("$to")

      # 遍历 platforms
      for platform in "${platforms[@]}"; do
        log_info "migrate" "from=$from to=$to platform=$platform"

        if [ "$test_mode" == "true" ]; then
          log_info "test_mode" "skip actual migration in test mode"
        else

          # 加入 digest 检查，如果 from 和 to 的 digest 相同，则跳过迁移
          if command_exists jq && command_exists skopeo; then
            if compare_image_layers "$from" "$to" "$platform"; then
              log_info "migrate" "image $to already exists with same layers for platform $platform, skipping migration"
              continue
            fi
            log_info "migrate" "image $to does not exist or has different layers for platform $platform, proceeding with migration"
          fi

          bash <(curl -sSL https://dev.kubectl.net/docker/tools/migrate_p.sh) \
            -s "$from" \
            -t "$to" \
            -p "$platform" \
            -x "re_pull"
        fi
      done
    done

    if [[ "$remove_after_migrate" == "true" && "$test_mode" == "false" ]]; then
      log_info "remove_images" "docker image rm -f ${migrated_images[*]}"
      if docker image rm -f "${migrated_images[@]}"; then
        log_info "remove_images" "local images removed after migration"
      else
        log_warn "remove_images" "failed to remove one or more local images"
      fi
    fi
  done
}

function main() {
  log_info "batch_migrate" "start batch migrate from docker hub to other registry"
  read_config_json
  migrate
  log_info "batch_migrate" "batch migrate completed"
}

main "$@"
