#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2155 disable=SC2128 disable=SC2028

set -euo pipefail # 严格模式：遇到错误立即退出，未定义变量报错

# 初始化根URI和依赖
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init) && export ROOT_URI=$ROOT_URI

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/ostype.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

# Windows环境配置
if is_windows; then
  log_info "build" "build in windows"
  export MSYS_NO_PATHCONV=1
fi

# 全局变量初始化
declare -g multi_platform="false"
declare -g path_to_dockerfile=""
declare -g build_dir=""
declare -g image_name=""
declare -g image_tag=""
declare -ga image_tag_list=()
declare -g re_tag_flag="true"
declare -g new_tag=""
declare -g push_flag="false"
declare -ga build_args=()
declare -g build_args_exec=""

log_info "docker build" ">>> docker build start <<<"

function cleanup() {
  log_info "docker build" ">>> docker build end <<<"
}
trap cleanup EXIT

function show_usage() {
  cat <<EOF
Docker Build Script Usage:
  -m  Multi platform (amd64 arm64), optional
  -d  Build directory, optional (if empty, uses Dockerfile's directory)
  -f  Path to dockerfile, optional
  -i  Image name (required)
  -v  Image tag (can be used multiple times)
  -r  Re-tag flag, default: true
  -t  New tag (if empty, uses timestamp)
  -p  Push flag, default: false
  -a  Build arg (can be used multiple times), format: KEY=VALUE

Examples:
  build.sh -i myapp -v latest -v v1.0
  build.sh -i myapp -v latest -p true -a ENV=prod -a VERSION=1.0
EOF
}

# 参数解析
function parse_arguments() {
  while getopts ":m:f:d:i:v:r:t:p:a:h" opt; do
    case ${opt} in
      m)
        log_info "get opts" "multi_platform: $OPTARG"
        multi_platform="$OPTARG"
        ;;
      d)
        log_info "get opts" "build_dir: $OPTARG"
        build_dir="$OPTARG"
        ;;
      f)
        log_info "get opts" "path_to_dockerfile: $OPTARG"
        path_to_dockerfile="$OPTARG"
        ;;
      i)
        log_info "get opts" "image_name: $OPTARG"
        image_name="$OPTARG"
        ;;
      v)
        log_info "get opts" "image_tag: $OPTARG"
        image_tag="$OPTARG"
        image_tag_list+=("$OPTARG")
        ;;
      r)
        log_info "get opts" "re_tag_flag: $OPTARG"
        re_tag_flag="$OPTARG"
        ;;
      t)
        log_info "get opts" "new_tag: $OPTARG"
        new_tag="$OPTARG"
        ;;
      p)
        log_info "get opts" "push_flag: $OPTARG"
        push_flag="$OPTARG"
        ;;
      a)
        log_info "get opts" "build_arg: $OPTARG"
        build_args+=("$OPTARG")
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

function print_params() {
  log_info "parameters" "=== Build Parameters ==="
  log_info "parameters" "path_to_dockerfile: $path_to_dockerfile"
  log_info "parameters" "build_dir: $build_dir"
  log_info "parameters" "image_name: $image_name"
  log_info "parameters" "image_tags: ${image_tag_list[*]}"
  log_info "parameters" "re_tag_flag: $re_tag_flag"
  log_info "parameters" "new_tag: $new_tag"
  log_info "parameters" "push_flag: $push_flag"
  log_info "parameters" "multi_platform: $multi_platform"
  if [ ${#build_args[@]} -gt 0 ]; then
    log_info "parameters" "build_args: ${build_args[*]}"
  fi
  log_info "parameters" "========================"
}

# 验证函数集合
function validate_not_blank() {
  local key="$1"
  local value="$2"
  if [ -z "$value" ]; then
    log_error "validation" "Parameter '$key' cannot be empty"
    show_usage
    exit 1
  fi
  log_info "validation" "Parameter '$key': $value"
}

function validate_docker_tag() {
  local docker_tag="$1"
  if [[ "$docker_tag" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}$ ]]; then
    log_info "validation" "Docker tag '$docker_tag' is valid"
    return 0
  else
    log_error "validation" "Docker tag '$docker_tag' is invalid"
    return 1
  fi
}

function validate_build_args() {
  local -a args=("$@")
  for build_arg in "${args[@]}"; do
    if [[ ! "$build_arg" =~ ^[a-zA-Z_][a-zA-Z0-9_]*=.*$ ]]; then
      log_error "validation" "Invalid build-arg format: '$build_arg' (expected KEY=VALUE)"
      exit 1
    fi
    log_info "validation" "Valid build-arg: $build_arg"
  done
}

function check_duplicate_tags() {
  local -a sorted_tags
  mapfile -t sorted_tags < <(printf '%s\n' "${image_tag_list[@]}" | sort)
  local -a unique_tags
  mapfile -t unique_tags < <(printf '%s\n' "${sorted_tags[@]}" | uniq)

  if [ ${#sorted_tags[@]} -ne ${#unique_tags[@]} ]; then
    log_error "validation" "Duplicate tags found in image_tag_list"
    exit 1
  fi
}

function prepare_params() {
  # 验证必需参数
  validate_not_blank "image_name" "$image_name"

  # 验证镜像标签
  if [ ${#image_tag_list[@]} -eq 0 ]; then
    log_error "validation" "At least one image tag is required (-v option)"
    show_usage
    exit 1
  fi

  # 验证每个标签和检查重复
  for tag in "${image_tag_list[@]}"; do
    validate_not_blank "image_tag" "$tag"
    validate_docker_tag "$tag" || exit 1
  done
  check_duplicate_tags

  # 验证构建参数
  if [ ${#build_args[@]} -gt 0 ]; then
    validate_build_args "${build_args[@]}"
  fi

  # 标准化布尔值
  case "${re_tag_flag,,}" in
    true | yes | 1) re_tag_flag="true" ;;
    *) re_tag_flag="false" ;;
  esac

  case "${push_flag,,}" in
    true | yes | 1) push_flag="true" ;;
    *) push_flag="false" ;;
  esac

  case "${multi_platform,,}" in
    true | yes | 1) multi_platform="true" ;;
    *) multi_platform="false" ;;
  esac

  # 处理新标签
  if [ "$re_tag_flag" == "true" ]; then
    prepare_new_tag
  fi

  # 生成构建参数
  generate_build_args_exec
}

function prepare_new_tag() {
  local timestamp_tag
  timestamp_tag=$(date '+%Y-%m-%d_%H-%M-%S')

  if [ -z "$new_tag" ]; then
    log_info "new_tag" "New tag is empty, using timestamp: $timestamp_tag"
    new_tag="$timestamp_tag"
  elif ! validate_docker_tag "$new_tag"; then
    log_error "validation" "New tag '$new_tag' is invalid"
    exit 1
  else
    # 检查新标签是否与现有标签冲突
    for existing_tag in "${image_tag_list[@]}"; do
      if [ "$new_tag" == "$existing_tag" ]; then
        log_error "validation" "New tag '$new_tag' conflicts with existing tag"
        exit 1
      fi
    done

    # 检查镜像是否已存在
    if docker image ls "$image_name" | grep -q -E "\\b$new_tag\\b"; then
      log_info "new_tag" "Image $image_name:$new_tag already exists, using timestamp: $timestamp_tag"
      new_tag="$timestamp_tag"
    fi
  fi
}

function generate_build_args_exec() {
  build_args_exec=""
  if [ ${#build_args[@]} -eq 0 ]; then
    log_info "build_args" "No build arguments provided"
    return
  fi

  for build_arg in "${build_args[@]}"; do
    build_args_exec="$build_args_exec --build-arg $build_arg"
  done
  if [ -n "$build_args_exec" ]; then
    log_info "build_args" "Build arguments: $build_args_exec"
  fi
}

# Dockerfile和构建目录准备
function prepare_dockerfile_and_build_dir() {
  # 查找Dockerfile
  if [ -z "$path_to_dockerfile" ]; then
    log_info "dockerfile" "Searching for default Dockerfile..."
    # 优先 Dockerfile
    local dockerfile_candidates=("Dockerfile" "DOCKERFILE" "dockerfile")

    for candidate in "${dockerfile_candidates[@]}"; do
      if [ -f "$candidate" ]; then
        path_to_dockerfile="$candidate"
        log_info "dockerfile" "Found: $path_to_dockerfile"
        break
      fi
    done

    if [ -z "$path_to_dockerfile" ]; then
      log_error "dockerfile" "No Dockerfile found. Tried: ${dockerfile_candidates[*]}"
      exit 1
    fi
  elif [ ! -f "$path_to_dockerfile" ]; then
    log_error "dockerfile" "Dockerfile not found: $path_to_dockerfile"
    exit 1
  fi

  # 确定构建目录
  local dockerfile_dir
  if is_windows; then
    dockerfile_dir=$(cd "$(dirname "$path_to_dockerfile")" && pwd -W)
  else
    dockerfile_dir=$(cd "$(dirname "$path_to_dockerfile")" && pwd)
  fi

  if [ -z "$build_dir" ]; then
    build_dir="$dockerfile_dir"
    log_info "build_dir" "Using Dockerfile directory: $build_dir"
  elif [ ! -d "$build_dir" ]; then
    log_error "build_dir" "Build directory not found: $build_dir"
    exit 1
  fi

  log_info "dockerfile" "Build context: $build_dir, Dockerfile: $path_to_dockerfile"
}

# Docker构建和推送
function build_and_push_image() {
  local target_tag="$1"
  local should_push="$2"

  # 构建镜像
  if [ "$multi_platform" == "true" ]; then
    log_info "docker_build" "Building multi-platform image: docker buildx build --platform linux/amd64,linux/arm64 -f $path_to_dockerfile $build_args_exec -t $image_name:$target_tag $build_dir"
    docker buildx build --platform linux/amd64,linux/arm64 -f "$path_to_dockerfile" $build_args_exec -t "$image_name:$target_tag" "$build_dir"
  else
    log_info "docker_build" "Building image: docker build -f $path_to_dockerfile $build_args_exec -t $image_name:$target_tag $build_dir"
    docker build -f "$path_to_dockerfile" $build_args_exec -t "$image_name:$target_tag" "$build_dir"
  fi

  if [ $? -ne 0 ]; then
    log_error "docker_build" "Docker build failed for $image_name:$target_tag"
    exit 1
  fi

  log_info "docker_build" "Successfully built $image_name:$target_tag"

  # 推送镜像
  if [ "$should_push" == "true" ]; then
    log_info "docker_push" "Pushing image: $image_name:$target_tag"
    docker push "$image_name:$target_tag"
    if [ $? -eq 0 ]; then
      log_info "docker_push" "Successfully pushed $image_name:$target_tag"
    else
      log_error "docker_push" "Failed to push $image_name:$target_tag"
      exit 1
    fi
  fi
}

function tag_and_push_image() {
  local source_tag="$1"
  local target_tag="$2"
  local should_push="$3"

  if [ "$source_tag" != "$target_tag" ]; then
    log_info "docker_tag" "Tagging image: $image_name:$source_tag -> $image_name:$target_tag"
    docker tag "$image_name:$source_tag" "$image_name:$target_tag"

    if [ "$should_push" == "true" ]; then
      log_info "docker_push" "Pushing tagged image: $image_name:$target_tag"
      docker push "$image_name:$target_tag"
      if [ $? -eq 0 ]; then
        log_info "docker_push" "Successfully pushed $image_name:$target_tag"
      else
        log_error "docker_push" "Failed to push $image_name:$target_tag"
      fi
    fi
  fi
}

function build_push() {
  local primary_tag="${image_tag_list[0]}"

  # 构建主要标签的镜像
  build_and_push_image "$primary_tag" "$push_flag"

  # 为其他标签创建别名
  for target_tag in "${image_tag_list[@]}"; do
    tag_and_push_image "$primary_tag" "$target_tag" "$push_flag"
  done
}

function re_tag_push() {
  local source_tag="${image_tag_list[0]}"

  if docker image ls "$image_name" | grep -q -E "\\b$source_tag\\b"; then
    log_info "re_tag" "Found existing image: $image_name:$source_tag"
    tag_and_push_image "$source_tag" "$new_tag" "$push_flag"
  else
    log_info "re_tag" "Image not found: $image_name:$source_tag, skipping re-tag"
  fi
}

# 检查Docker环境并执行构建
function check_docker_and_build() {
  if ! command_exists docker; then
    log_error "docker" "Docker command not found. Please install Docker first."
    exit 1
  fi

  log_info "docker" "Docker command available"

  # 执行构建流程
  if [ "$re_tag_flag" == "true" ]; then
    log_info "workflow" "Executing re-tag and build workflow"
    re_tag_push
    build_push
  else
    log_info "workflow" "Executing build workflow"
    build_push
  fi
}

# 主执行流程
function main() {
  parse_arguments "$@"
  print_params
  prepare_params
  prepare_dockerfile_and_build_dir
  check_docker_and_build
  log_info "docker build" "All operations completed successfully"
}

# 执行主函数
main "$@"
