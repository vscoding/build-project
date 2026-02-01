#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2028
# 严格模式：遇到错误立即退出，未定义变量报错
set -euo pipefail

# 初始化根URI和依赖
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/ostype.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

# 全局变量初始化
declare -g image=""
declare -g build_cmd=""
declare -g build_dir=""

log "node build" ">>> start <<<"

function cleanup() {
  log "node build" ">>> end <<<"
}
trap cleanup EXIT

function show_usage() {
  cat <<EOF
Node.js Build Script Usage:
  -i  Node.js Docker image (required)
  -x  Node.js build command (required), e.g.: "npm install && npm run build"
  -d  Project build directory (optional, default: current directory)
  -h  Show this help message

Examples:
  ./build.sh -i node:18-alpine -x "npm install && npm run build"
  ./build.sh -i node:16 -x "npm ci && npm run test" -d /path/to/project
  ./build.sh -i node:latest -x "yarn install && yarn build"
EOF
}

function parse_arguments() {
  while getopts ":i:x:d:h" opt; do
    case ${opt} in
    d)
      log_info "get opts" "build_dir: $OPTARG"
      build_dir="$OPTARG"
      ;;
    i)
      log_info "get opts" "docker image: $OPTARG"
      image="$OPTARG"
      ;;
    x)
      log_info "get opts" "node command: $OPTARG"
      build_cmd="$OPTARG"
      ;;
    h)
      show_usage
      exit 0
      ;;
    \?)
      log_error "get opts" "Invalid option: -$OPTARG"
      show_usage
      exit 1
      ;;
    :)
      log_error "get opts" "Option -$OPTARG requires an argument"
      show_usage
      exit 1
      ;;
    esac
  done
}

function validate_params() {
  local required_params=("image" "build_cmd")

  # 验证必需参数
  for param in "${required_params[@]}"; do
    if [ -z "${!param}" ]; then
      log_error "validation" "Parameter '$param' is required"
      show_usage
      exit 1
    fi
    log_info "validation" "$param: ${!param}"
  done

  # 验证构建目录
  if [ -z "$build_dir" ]; then
    build_dir="$(pwd)"
    log_info "build_dir" "Using current directory: $build_dir"
  elif [ ! -d "$build_dir" ]; then
    log_error "build_dir" "Build directory not found: $build_dir"
    exit 1
  fi

  # 验证Docker命令
  if ! command_exists docker; then
    log_error "docker" "Docker command not found. Please install Docker first."
    exit 1
  fi
  log_info "docker" "Docker command available"
}

function execute_node_build() {
  log_info "build" "=== Starting Node.js build in Docker ==="
  log_info "build" "Image: $image"
  log_info "build" "Command: $build_cmd"
  log_info "build" "Build directory: $build_dir"

  local docker_args=(
    "--rm"
    "-u" "root"
    "-v" "$build_dir:/opt/app/node"
    "-w" "/opt/app/node"
  )

  # Windows环境特殊处理
  if is_windows; then
    log_info "build" "Windows environment detected"
    export MSYS_NO_PATHCONV=1
  else
    log_info "build" "Linux environment detected"
    docker_args+=("--network=host")
  fi

  log_info "build" "Executing: docker run ${docker_args[*]} $image $build_cmd"

  docker run "${docker_args[@]}" "$image" $build_cmd

  if [ $? -eq 0 ]; then
    log_info "build" "Node.js build completed successfully"
  else
    log_error "build" "Node.js build failed"
    exit 1
  fi
}

# 主执行流程
function main() {
  parse_arguments "$@"
  validate_params
  execute_node_build
  log_info "build" "All operations completed successfully"
}

# 执行主函数
main "$@"
