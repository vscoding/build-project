#!/bin/bash
# shellcheck disable=SC1090 disable=SC2162
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
set -euo pipefail

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

log_info "migrate" "migrate docker's image"

if ! command_exists docker; then
  log_error "migrate" "docker not found, please install docker first"
  exit 1
fi

declare -g from=""
declare -a to_list=()
declare -a platforms=()
declare -g pull_action=""

function show_usage() {
  cat <<EOF
Usage: migrate_p.sh [options]
Options:
  -s <from>       Source image name (e.g., openjdk:8-jdk)
  -t <to>         Target image name (e.g., registry.cn-shanghai.aliyuncs.com/iproute/openjdk:8-jdk)
  -p <platform>   Platform to pull (e.g., linux/amd64, linux/arm64)
  -x              Pull action (e.g., skip_pull ,re_pull)
  -h              Show this help message
EOF
}

function parse_params() {
  while getopts ":s:t:p:x:h" opt; do
    case ${opt} in
      s)
        log_info "get opts" "from: $OPTARG"
        from=$OPTARG
        ;;
      t)
        log_info "get opts" "to: $OPTARG"
        to_list+=("$OPTARG")
        ;;
      p)
        log_info "get opts" "platforms: $OPTARG"
        platforms+=("$OPTARG")
        ;;
      x)
        log_info "get opts" "pull_action: $OPTARG"
        pull_action=$OPTARG
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
  [[ -z "$from" ]] && {
    log_error "validate params" "Source image name (-s) is required"
    show_usage
    exit 1
  }

  [[ ${#to_list[@]} -eq 0 ]] && {
    log_error "validate params" "Target image name (-t) is required"
    show_usage
    exit 1
  }

  [[ ${#platforms[@]} -eq 0 ]] && {
    log_info "validate params" "No platforms specified, defaulting to linux/amd64"
    platforms=("linux/amd64")
  }

  [[ -z "$pull_action" ]] && {
    log_info "validate params" "No pull action specified, defaulting to other"
    pull_action="other"
  }

  log_info "validate params" "from: $from, to_list: ${to_list[*]}, platforms: ${platforms[*]}, pull_action: $pull_action"
}

function migrate() {
  function docker_image_exists() {
    local image_name_tag="$1"
    log_info "image_exists" "docker image inspect $image_name_tag &>/dev/null"
    if docker image inspect "$image_name_tag" &>/dev/null; then
      log_info "image_exists" "Image $image_name_tag exists"
      return 0
    else
      log_error "image_exists" "Image $image_name_tag does not exist"
      return 1
    fi
  }

  function docker_pull() {
    local image_name_tag="$1"
    local platform="$2"
    local pull_action="$3"

    if [ "$pull_action" == "skip_pull" ]; then
      if docker_image_exists "$image_name_tag"; then
        log_info "pull" "Image $image_name_tag already exists, skipping pull"
        return 0
      else
        log_error "pull" "Image $image_name_tag not found, skipping pull"
        return 1
      fi
    elif [ "$pull_action" == "re_pull" ]; then
      if docker_image_exists "$image_name_tag"; then
        log_info "pull" "Image $image_name_tag already exists, re-pulling for platform $platform"
      else
        log_info "pull" "Image $image_name_tag not found, pulling for platform $platform"
      fi

      log_info "pull" "docker pull --platform $platform $image_name_tag"
      if docker pull --platform "$platform" "$image_name_tag"; then
        log_info "pull" "Successfully pulled image $image_name_tag for platform $platform"
        return 0
      else
        log_error "pull" "docker pull --platform $platform $image_name_tag failed"
        return 1
      fi
    else
      if ! docker_image_exists "$image_name_tag"; then
        read -p "Image $image_name_tag not found, do you want to pull it? [default: y] (y/n): " answer
        if [[ -z "$answer" ]]; then
          answer="y"
        fi
        if docker pull --platform "$platform" "$image_name_tag"; then
          log_info "pull" "Successfully pulled image $image_name_tag for platform $platform"
          return 0
        else
          log_error "pull" "docker pull --platform $platform $image_name_tag failed"
          return 1
        fi
      else
        if docker pull --platform "$platform" "$image_name_tag"; then
          log_info "pull" "Successfully pulled image $image_name_tag for platform $platform"
          return 0
        else
          log_error "pull" "docker pull --platform $platform $image_name_tag failed"
          return 1
        fi
      fi

    fi

  }

  function docker_push() {
    local image_name_tag="$1"
    local target_name_tag="$2"
    local platform="$3"

    if docker_image_exists "$image_name_tag"; then
      log_info "push" "Image $image_name_tag exists, tagging to $target_name_tag"
      docker tag "$image_name_tag" "$target_name_tag"

      log_info "push" "Pushing image $target_name_tag for platform $platform"
      docker push --platform "$platform" "$target_name_tag"
      return $?
    else
      log_error "push" "Image $image_name_tag does not exist, cannot push to $target_name_tag"
      return 1
    fi
  }

  function do_migrate() {

    for platform in "${platforms[@]}"; do
      log_info "migrate" "Processing platform: $platform"
      if ! docker_pull "$from" "$platform" "$pull_action"; then
        log_error "migrate" "Failed to pull image $from for platform $platform"
        continue
      else
        log_info "migrate" "Successfully pulled image $from for platform $platform"
        for to in "${to_list[@]}"; do
          if docker_push "$from" "$to" "$platform"; then
            log_info "migrate" "Successfully pushed $from to $to for platform $platform"
          else
            log_error "migrate" "Failed to push $from to $to for platform $platform"
          fi
        done
      fi
    done
  }

  do_migrate
}

function main() {
  parse_params "$@"
  validate_params
  migrate
}

main "$@"
