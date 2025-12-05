#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2028 disable=SC2155 disable=SC2181

set -euo pipefail # 严格模式：遇到错误立即退出，未定义变量报错

# 初始化根URI和依赖
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/ostype.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

# 全局变量初始化
declare -g build_dir=""
declare -g instance=""
declare -gr BUILD_IMAGE="registry.cn-shanghai.aliyuncs.com/iproute/wrs-builder:2025.04.8412"

log "wsr build" ">>> writerside build start <<<"

function cleanup() {
  log "wsr build" ">>> writerside build end <<<"
}
trap cleanup EXIT

function show_usage() {
  cat <<EOF
Writerside Build Script Usage:
  -i  Writerside instance name (required)
  -d  Writerside project directory (optional, default: current directory)
  -h  Show this help message

Description:
  This script builds Writerside documentation using Docker.
  The build requires a 'Writerside' directory in the project root.

Examples:
  ./build.sh -i my-docs
  ./build.sh -i my-docs -d /path/to/project
  
Build Image: $BUILD_IMAGE
EOF
}

function parse_arguments() {
  while getopts ":d:i:h" opt; do
    case ${opt} in
    d)
      log_info "get opts" "build_dir: $OPTARG"
      build_dir="$OPTARG"
      ;;
    i)
      log_info "get opts" "instance: $OPTARG"
      instance="$OPTARG"
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
  # 验证必需参数
  if [ -z "$instance" ]; then
    log_error "validation" "Parameter 'instance' is required"
    show_usage
    exit 1
  fi
  log_info "validation" "instance: $instance"

  # 验证或设置构建目录
  if [ -z "$build_dir" ]; then
    build_dir="$(pwd)"
    log_info "build_dir" "Using current directory: $build_dir"
  fi

  # 验证构建目录存在
  if [ ! -d "$build_dir" ]; then
    log_error "build_dir" "Build directory not found: $build_dir"
    exit 1
  fi

  # 验证Writerside目录存在
  if [ ! -d "$build_dir/Writerside" ]; then
    log_error "validation" "Writerside directory not found in: $build_dir"
    log_error "validation" "Please ensure the project contains a 'Writerside' directory"
    exit 1
  fi
  log_info "validation" "Writerside directory found: $build_dir/Writerside"

  # 验证Docker命令
  if ! command_exists docker; then
    log_error "docker" "Docker command not found. Please install Docker first."
    exit 1
  fi
  log_info "docker" "Docker command available"
}

function prepare_build_environment() {
  # 清理输出目录
  local output_dir="$build_dir/output"
  if [ -d "$output_dir" ]; then
    log_info "cleanup" "Removing existing output directory: $output_dir"
    rm -rf "$output_dir"
  fi

  # Windows环境特殊处理
  if is_windows; then
    log_info "environment" "Windows environment detected"
    export MSYS_NO_PATHCONV=1
  else
    log_info "environment" "Linux environment detected"
  fi
}

function execute_writerside_build() {
  log_info "build" "=== Starting Writerside documentation build ==="
  log_info "build" "Build image: $BUILD_IMAGE"
  log_info "build" "Instance: $instance"
  log_info "build" "Project directory: $build_dir"

  local docker_args=(
    "--rm"
    "-v" "$build_dir:/opt/sources"
    "-e" "INSTANCE=$instance"
  )

  log_info "build" "Executing: docker run ${docker_args[*]} $BUILD_IMAGE"

  docker run "${docker_args[@]}" "$BUILD_IMAGE"

  if [ $? -eq 0 ]; then
    log_info "build" "Writerside build completed successfully"

    # 检查输出目录
    local output_dir="$build_dir/output"
    if [ -d "$output_dir" ]; then
      log_info "build" "Build output available in: $output_dir"
      local file_count=$(find "$output_dir" -type f | wc -l)
      log_info "build" "Generated $file_count files"
    else
      log_warn "build" "Output directory not found: $output_dir"
    fi
  else
    log_error "build" "Writerside build failed"
    exit 1
  fi
}

# 主执行流程
function main() {
  parse_arguments "$@"
  validate_params
  prepare_build_environment
  execute_writerside_build
  log_info "build" "All operations completed successfully"
}

# 执行主函数
main "$@"
