#!/bin/bash
# shellcheck disable=SC2086 disable=SC2155 disable=SC1090 disable=SC2028

set -euo pipefail # 严格模式：遇到错误立即退出，未定义变量报错

# 初始化根URI和依赖
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/ostype.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

# 全局变量初始化
declare -g cache=""
declare -g image=""
declare -g build_cmd=""
declare -g build_dir=""

log_info "gradle build" ">>> start <<<"

function cleanup() {
  log_info "gradle build" ">>> end <<<"
}
trap cleanup EXIT

function show_usage() {
  cat <<EOF
Gradle Build Script Usage:
  -i  Gradle Docker image (required)
  -x  Gradle build command (required), e.g.: "gradlew build"
  -c  Docker volume name for cache (required)
  -d  Project build directory (optional, default: current directory)
  -h  Show this help message

Examples:
  build.sh -i gradle:7.6-jdk17 -x "gradle build" -c gradle-cache
  build.sh -i gradle:7.6-jdk17 -x "gradlew clean build" -c gradle-cache -d /path/to/project
EOF
}

function parse_arguments() {
  while getopts ":c:i:x:d:h" opt; do
    case ${opt} in
      d)
        log_info "get opts" "build_dir: $OPTARG"
        build_dir="$OPTARG"
        ;;
      c)
        log_info "get opts" "cache volume: $OPTARG"
        cache="$OPTARG"
        ;;
      i)
        log_info "get opts" "docker image: $OPTARG"
        image="$OPTARG"
        ;;
      x)
        log_info "get opts" "gradle command: $OPTARG"
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
  local required_params=("cache" "image" "build_cmd")

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
    log_warn "build_dir" "Using current directory: $build_dir"
  elif [ ! -d "$build_dir" ]; then
    log_error "build_dir" "Build directory not found: $build_dir"
    exit 1
  fi

  # 验证缓存卷名称格式
  if [[ ! "$cache" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    log_error "validation" "Cache volume name contains invalid characters: $cache"
    log_error "validation" "Only alphanumeric, underscore, dot, and hyphen are allowed"
    exit 1
  fi
  log_info "validation" "Cache volume name is valid: $cache"

  # 验证Docker命令
  if ! command_exists docker; then
    log_error "docker" "Docker command not found. Please install Docker first."
    exit 1
  fi
  log_info "docker" "Docker command available"
}

function execute_gradle_build() {
  log_info "build" "=== Starting Gradle build in Docker ==="
  log_info "build" "Image: $image"
  log_info "build" "Command: $build_cmd"
  log_info "build" "Build directory: $build_dir"
  log_info "build" "Cache volume: $cache"

  local docker_args=(
    "--rm"
    "-u" "root"
    "-v" "$build_dir:/home/gradle/project"
    "-w" "/home/gradle/project"
    "-v" "$cache:/home/gradle/.gradle"
  )

  # Windows环境特殊处理
  if is_windows; then
    log_info "build" "Windows environment detected"
    export MSYS_NO_PATHCONV=1
  else
    log_info "build" "Linux environment detected"
    docker_args+=("--network" "host")
  fi

  log_info "build" "Executing: docker run ${docker_args[*]} $image $build_cmd"

  docker run "${docker_args[@]}" "$image" $build_cmd

  if [ $? -eq 0 ]; then
    log_info "build" "Gradle build completed successfully"
  else
    log_error "build" "Gradle build failed"
    exit 1
  fi
}

# 主执行流程
function main() {
  parse_arguments "$@"
  validate_params
  execute_gradle_build
  log_info "build" "All operations completed successfully"
}

# 执行主函数
main "$@"
