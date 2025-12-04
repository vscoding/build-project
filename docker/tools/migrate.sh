#!/bin/bash
# shellcheck disable=SC1090 disable=SC2162
[ -z $ROOT_URI ] && source <(curl -sSL https://gitlab.com/iprt/shell-basic/-/raw/main/build-project/basic.sh)
set -euo pipefail

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

log_info "migrate" "migrate docker's image"

if ! command_exists docker; then
  log_error "migrate" "docker not found, please install docker first"
  exit 1
fi

from_image="${1:-}"
to_image="${2:-}"
skip_pull="${3:-n}"

[[ -z "$skip_pull" ]] && {
  skip_pull="n"
}

[[ -z "$from_image" ]] && {
  log_error "migrate" "from_image is empty"
  exit 1
}

[[ -z "$to_image" ]] && {
  log_error "migrate" "to_image is empty"
  exit 1
}

log_info "migrate" "from: $from_image ==> to: $to_image"

function image_exists() {
  local image_name_tag="$1"
  docker image inspect "$image_name_tag" &>/dev/null
  return $?
}

function docker_pull() {
  local image_name_tag="$1"
  if ! docker pull --platform linux/amd64 "$image_name_tag"; then
    log_error "migrate" "docker pull --platform linux/amd64 $image_name_tag failed"
    exit 1
  fi
}

# 如果镜像存在，判断是否要再次pull
if image_exists "$from_image"; then
  if [ "$skip_pull" == "skip_pull" ]; then
    log_info "migrate" "Image $from_image already exists, skip pull"
  elif [ "$skip_pull" == "re_pull" ]; then
    log_info "migrate" "Image $from_image already exists, re-pulling..."
    docker_pull "$from_image"
  else
    # 判断是否要再次pull
    read -p "Image $from_image already exists, do you want to pull it again?[default: y] (y/n) :" answer
    if [ -z "$answer" ]; then
      answer="y"
    fi

    if [ "$answer" == "y" ]; then
      docker_pull "$from_image"
    fi
  fi
else
  if [ "$skip_pull" == "skip_pull" ]; then
    log_info "migrate" "Image $from_image not found,skip pull, exit..."
    exit 0
  fi

  log_info "migrate" "Image $from_image not found, pulling..."
  docker_pull "$from_image"
fi

# 再次判断镜像是否存在
if image_exists "$from_image"; then
  docker tag "$from_image" "$to_image"
  docker push --platform linux/amd64 "$to_image"
fi
