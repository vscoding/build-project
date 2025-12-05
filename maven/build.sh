#!/bin/bash
# shellcheck disable=SC2086 disable=SC2155 disable=SC1090 disable=SC2028

# 严格模式：遇到错误立即退出，未定义变量报错
set -euo pipefail

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
declare -g settings=""

log_info "maven build" ">>> start <<<"

function cleanup() {
  log_info "maven build" ">>> end <<<"
}
trap cleanup EXIT

function show_usage() {
  cat <<EOF
Maven Build Script Usage:
  -i  Maven Docker image (required)
  -x  Maven build command (required), e.g.: "mvn clean install"
  -c  Docker volume name for cache (required)
  -s  Path to settings.xml file (required)
  -d  Project build directory (optional, default: current directory)
  -h  Show this help message

Examples:
  build.sh -i maven:3.8-openjdk-17 -x "mvn clean install" -c maven-cache -s ./settings.xml
  build.sh -i maven:3.8-openjdk-17 -x "mvn package" -c maven-cache -s ./settings.xml -d /path/to/project
EOF
}

function parse_arguments() {
  while getopts ":c:i:x:s:d:h" opt; do
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
      log_info "get opts" "maven command: $OPTARG"
      build_cmd="$OPTARG"
      ;;
    s)
      log_info "get opts" "settings.xml: $OPTARG"
      settings="$OPTARG"
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
  local required_params=("cache" "image" "build_cmd" "settings")

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

  # 验证缓存卷名称格式
  if [[ ! "$cache" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    log_error "validation" "Cache volume name contains invalid characters: $cache"
    log_error "validation" "Only alphanumeric, underscore, dot, and hyphen are allowed"
    exit 1
  fi
  log_info "validation" "Cache volume name is valid: $cache"

  # 验证settings.xml文件
  if [ ! -f "$settings" ]; then
    log_error "validation" "Settings file not found: $settings"
    exit 1
  fi
  log_info "validation" "Settings file exists: $settings"

  # 验证Docker命令
  if ! command_exists docker; then
    log_error "docker" "Docker command not found. Please install Docker first."
    exit 1
  fi
  log_info "docker" "Docker command available"
}

function execute_maven_build() {
  log_info "build" "=== Starting Maven build in Docker ==="
  log_info "build" "Image: $image"
  log_info "build" "Command: $build_cmd"
  log_info "build" "Build directory: $build_dir"
  log_info "build" "Cache volume: $cache"
  log_info "build" "Settings file: $settings"

  local docker_args=(
    "-i"
    "--rm"
    "-u" "root"
    "-v" "$build_dir:/usr/src/app"
    "-w" "/usr/src/app"
    "-v" "$cache:/root/.m2/repository"
    "-v" "$settings:/usr/share/maven/ref/settings.xml"
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

  if docker run "${docker_args[@]}" "$image" $build_cmd; then
    log_info "build" "Maven build completed successfully"
  else
    log_error "build" "Maven build failed"
    exit 1
  fi

}

# 主执行流程
function main() {
  parse_arguments "$@"
  validate_params
  execute_maven_build
  log_info "build" "All operations completed successfully"
}

# 执行主函数
main "$@"
