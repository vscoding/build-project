#!/bin/bash
# shellcheck disable=SC2086 disable=SC2155 disable=SC2126 disable=SC1090 disable=SC2028
set -euo pipefail # 严格模式：遇到错误立即退出，使用未定义变量报错

[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init) && export ROOT_URI=$ROOT_URI
source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/ostype.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

# 全局变量声明
declare -g cache=""
declare -g image=""
declare -g build_cmd=""
declare -g build_dir=""

tap_exit() { log_info "go build" ">>> go build end <<<"; }
trap tap_exit EXIT

# 打印脚本用法
function show_usage() {
  cat <<EOF
Usage: build.sh -i IMAGE -x BUILD_CMD [-c CACHE_VOLUME] [-d BUILD_DIR] [-h]

Options:
  -i  Golang Docker image               (required)
  -x  Go build command                  (required), e.g.: "go build -o app"
  -c  Docker volume name for cache      (required)
  -d  Project build directory           (default: current dir)
  -h  Show this help message
EOF
}

function parse_arguments() {
  while getopts ":c:i:x:d:h" opt; do
    case $opt in
      c) cache="$OPTARG" ;;     # 缓存卷
      i) image="$OPTARG" ;;     # Docker镜像
      x) build_cmd="$OPTARG" ;; # 构建命令
      d) build_dir="$OPTARG" ;; # 构建目录
      h)
        show_usage
        exit 0
        ;;
      \?)
        log_info "get opts" "Invalid option: -$OPTARG"
        show_usage
        exit 1
        ;;
      :)
        log_info "get opts" "Option -$OPTARG requires an argument"
        show_usage
        exit 1
        ;;
    esac
  done
}

function validate_params() {
  # 检查必需参数
  for key in cache image build_cmd; do
    if [[ -z "${!key}" ]]; then
      log_error "validate" "$key is required"
      show_usage
      exit 1
    fi
    log_info "validate" "$key=${!key}"
  done

  # 构建目录
  if [[ -z "$build_dir" ]]; then
    build_dir="$(pwd)"
    log_info "build_dir" "Using current directory: $build_dir"
  elif [[ ! -d "$build_dir" ]]; then
    log_error "build_dir" "Build directory not found: $build_dir"
    exit 1
  fi

  # 缓存名合法性
  if [[ ! "$cache" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    log_error "validate" "Cache volume name invalid: $cache"
    exit 1
  fi

  # Docker命令
  command_exists docker || (log_error "docker" "docker not found" && exit 1)
}

function execute_build() {
  log_info "build" "Starting Go build in Docker"

  if is_windows; then
    log_info "build" "Windows detected, disabling path conversion"
    export MSYS_NO_PATHCONV=1
  fi

  docker run --rm \
    -v "$build_dir:/usr/src/myapp" \
    -w /usr/src/myapp \
    --network=host \
    -e CGO_ENABLED=0 \
    -e GOPROXY=https://goproxy.cn,direct \
    -e GOPATH=/opt/go \
    -v "$cache:/opt/go" \
    "$image" \
    $build_cmd
}

# 主流程
function main() {
  parse_arguments "$@"
  validate_params
  execute_build
}

main "$@"
