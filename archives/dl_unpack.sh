#!/bin/bash
# shellcheck disable=SC1090,SC2181
set -euo pipefail
IFS=$'\n\t'

[ -z "${ROOT_URI:-}" ] && ROOT_URI="https://dev.kubectl.org"
source <(curl -sSL "$ROOT_URI/func/log.sh")

declare -g download_url=""     # 下载链接
declare -g proxy=""            # 代理
declare -g output_file=""      # 下载后的文件命名
declare -g unpack_flag="false" # 是否解压，true解压，false不解压

function show_usage() {
  cat <<EOF
Usage: ./dl_unpack -r <url> [-o <filename>] [-x <proxy>] [-d <true|false>]

Options:
  -r   下载链接 (必填)
  -o   下载后的文件名 (默认取 URL basename)
  -x   代理 (如 http://127.0.0.1:7890)
  -d   是否解压 (true/false，默认 false)
  -h   显示帮助
EOF
}

function parse_arguments() {
  while getopts ":r:o:x:d:h" opt; do
    case ${opt} in
      r) download_url=$OPTARG ;;
      o) output_file="$OPTARG" ;;
      x) proxy="$OPTARG" ;;
      d) unpack_flag="$OPTARG" ;;
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

  if [[ -z "$download_url" ]]; then
    log_error "opts" "必须指定下载链接 (-r)"
    show_usage
    exit 1
  fi

  if [[ -z "$output_file" ]]; then
    output_file=$(basename "$download_url")
  fi
}

function download_archive() {
  local url=$1
  local proxy=$2
  local output_file=$3

  log_info "download" "开始下载: $url -> $output_file"

  if command -v curl >/dev/null 2>&1; then
    if [[ -n "$proxy" ]]; then
      curl -L --proxy "$proxy" -o "$output_file" "$url"
    else
      curl -L -o "$output_file" "$url"
    fi
  elif command -v wget >/dev/null 2>&1; then
    if [[ -n "$proxy" ]]; then
      wget -e "use_proxy=yes" -e "http_proxy=$proxy" -O "$output_file" "$url"
    else
      wget -O "$output_file" "$url"
    fi
  else
    log_error "download" "缺少 curl 或 wget"
    exit 1
  fi
}

function unpack_archive() {
  local file=$1

  log_info "unpack" "解压文件: $file"

  case "$file" in
    *.tar.gz | *.tgz) tar -xzf "$file" ;;
    *.tar.bz2) tar -xjf "$file" ;;
    *.tar.xz) tar -xJf "$file" ;;
    *.zip) unzip -o "$file" ;;
    *) log_warn "unpack" "不支持的格式: $file" ;;
  esac
}

# === main ===
parse_arguments "$@"
download_archive "$download_url" "$proxy" "$output_file"

if [[ "$unpack_flag" == "true" ]]; then
  unpack_archive "$output_file"
fi
