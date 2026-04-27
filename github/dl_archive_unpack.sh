#!/bin/bash
# shellcheck disable=SC1090,SC2181
set -euo pipefail
IFS=$'\n\t'

# 初始化 ROOT_URI
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)
source <(curl -sSL "$ROOT_URI/func/log.sh")

declare -g repo=""
declare -g target_name=""
declare -g proxy=""
declare -g specified_version=""
declare -g version=""

function show_usage() {
  cat <<EOF
GitHub Repo Downloader & Unpacker

Usage:
  $(basename "$0") -r <repo> [-o <dir>] [-x <proxy>] [-v <version>] [-h]

Options:
  -r  GitHub repository (必填)，如 "openresty/lua-nginx-module"
  -o  解压后的目录名 (可选)，默认与 repo 最后一级同名
  -x  代理 (可选)，支持 http:// https:// socks5:// socks5h://
  -v  指定 tag 版本 (可选)，默认使用最新 tag
  -h  显示帮助信息

Examples:
  bash <(curl -sSL https://yourdomain/dl_unpack.sh) -r openresty/lua-nginx-module
  bash <(curl -sSL https://yourdomain/dl_unpack.sh) -r openresty/lua-resty-core -v v0.1.20
EOF
}

function parse_arguments() {
  while getopts ":r:o:x:v:h" opt; do
    case ${opt} in
      r) repo="$OPTARG" ;;
      o) target_name="$OPTARG" ;;
      x) proxy="$OPTARG" ;;
      v) specified_version="$OPTARG" ;;
      h)
        show_usage
        exit 0
        ;;
      \?)
        log_error "opts" "Invalid option: -$OPTARG"
        show_usage
        exit 1
        ;;
      :)
        log_error "opts" "Option -$OPTARG requires an argument"
        show_usage
        exit 1
        ;;
    esac
  done
}

source <(curl -sSL "$ROOT_URI/github/api.sh")
tmp_target_name=""
function validate_params() {
  [[ -z $repo ]] && {
    log_error "validate" "Repository cannot be empty"
    show_usage
    exit 1
  }

  if [ -z "$target_name" ]; then
    tmp_target_name=$(basename "$repo")
    log_warn "validate" "Target dir not specified, using default: $target_name"
  else
    tmp_target_name="$target_name"
    log_info "validate" "Using specified target dir: $target_name"
  fi

  if [ -n "$proxy" ]; then
    if [[ ! "$proxy" =~ ^(http://|https://|socks5://|socks5h://) ]]; then
      log_error "validate" "Invalid proxy format: $proxy"
      exit 1
    fi
  fi

  if [ -z "$specified_version" ]; then
    log_info "validate" "No version specified, fetching latest tag"
    version=$(fetch_latest_tag "$repo" "$proxy")
    [[ -z "$version" ]] && {
      log_error "validate" "Failed to fetch latest tag for $repo"
      exit 1
    }
  else
    log_info "validate" "Using specified version: $specified_version"
    version="$specified_version"
  fi

  log_info "validate" "repo=$repo, target_name=$tmp_target_name, proxy=$proxy, version=$version"
}

function download_and_unpack() {
  local download_url="https://github.com/$repo/archive/refs/tags/$version.tar.gz"
  local output_file="${tmp_target_name}-${version}.tar.gz"

  log_info "download" "url=$download_url"
  log_info "download" "output=$output_file"

  rm -f "$output_file"
  local curl_opts=(-SL -o "$output_file")
  [ -n "$proxy" ] && curl_opts+=(-x "$proxy")
  curl "${curl_opts[@]}" "$download_url"

  # 解压
  tar zxvf "$output_file"

  get_top_dir() {
    local archive="$1"

    # 使用 GNU tar，并只取第一行
    local first_line
    first_line=$(/usr/bin/tar -tzf "$archive" 2>/dev/null | head -1)

    # 如果 /usr/bin/tar 不存在（Windows Git Bash 环境），尝试使用系统 tar
    if [ -z "$first_line" ]; then
      first_line=$(tar -tzf "$archive" 2>/dev/null | head -1)
    fi

    # 替换反斜杠为斜杠，去除回车符
    first_line=$(echo "$first_line" | sed 's|\\|/|g' | tr -d '\r')

    # 提取第一层目录名
    echo "$first_line" | cut -f1 -d"/"
  }

  # 自动推断解压目录
  local unpacked_dir
  unpacked_dir=$(get_top_dir "$output_file")

  if [ -n "$target_name" ]; then
    rm -rf "$target_name"
    mv "$unpacked_dir" "$target_name"
    log_info "unpack" "Directory renamed to: $target_name"
  fi
}

function main() {
  parse_arguments "$@"
  validate_params
  download_and_unpack
}

main "$@"
