#!/bin/bash
# shellcheck disable=SC2086,SC2046,SC2126,SC2155,SC1090,SC2028
set -euo pipefail
IFS=$'\n\t'

[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL "$ROOT_URI/func/log.sh")

log_info "docker rmi" ">>> docker rmi start <<<"

function end() {
  log_info "docker rmi" ">>> docker rmi end <<<"
}

function show_usage() {
  cat >&2 <<EOF
Usage: rmi.sh -i <image_name> [-s <strategy>]
Options:
  -i <image_name>   Docker 镜像名 (必填)
  -s <strategy>     删除策略，可选:
                      contain_latest (默认)  - 删除除 latest 外的镜像
                      remove_none           - 删除 <none> 镜像
                      all                   - 删除该镜像的所有版本
Example:
  rmi.sh -i my_image -s contain_latest
EOF
  end
}

declare -g image_name=""
declare -g strategy="contain_latest"

function parse_params() {
  while getopts ":i:s:" opt; do
    case ${opt} in
      i)
        log_info "get opts" "image name: $OPTARG"
        image_name=$OPTARG
        ;;
      s)
        log_info "get opts" "remove strategy: $OPTARG"
        strategy=$OPTARG
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
  if [[ -z "$image_name" ]]; then
    log_error "validate" "parameter image_name is empty"
    show_usage
    exit 1
  fi
  log_info "validate" "image_name: $image_name"
  log_info "validate" "strategy: $strategy"
}

function clean_image() {
  # 跳过表头 NR>1
  local images
  case "$strategy" in
    contain_latest)
      images=$(docker image ls "$image_name" | awk 'NR>1 && $2!="latest" {print $3}')
      ;;
    remove_none)
      images=$(docker image ls "$image_name" | awk 'NR>1 && $2=="<none>" {print $3}')
      ;;
    all)
      images=$(docker image ls "$image_name" | awk 'NR>1 {print $3}')
      ;;
    *)
      log_error "clean_image" "Unknown strategy: $strategy"
      show_usage
      exit 1
      ;;
  esac

  if [[ -z "${images:-}" ]]; then
    log_warn "$strategy" "no images matched, nothing to remove"
  else
    log_info "$strategy" "removing images: $images"
    docker image rm -f $images
  fi
  end
}

function main() {
  parse_params "$@"
  validate_params
  clean_image
}

main "$@"
