#!/bin/bash
# shellcheck disable=SC2164 disable=SC2086 disable=SC1090
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/ostype.sh)

if is_windows; then
  log_error "validate" "Windows is not supported for docker installation."
  exit 1
fi

arch="x86_64"
version="28.0.4"

function show_usage() {
  cat <<EOF
Usage: $0 [--platform|-p <platform>] [--version|-v <version>]

Options:
  -p, --platform  Docker platform architecture, default: x86_64
  -v, --version   Docker version, default: 28.0.4
  -h, --help      Show this help message
EOF
}

function parse_arguments() {
  local -a normalized_args=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --platform)
        if [ $# -lt 2 ]; then
          log_error "get opts" "Option --platform requires an argument"
          show_usage
          exit 1
        fi
        normalized_args+=("-p" "$2")
        shift 2
        ;;
      --version)
        if [ $# -lt 2 ]; then
          log_error "get opts" "Option --version requires an argument"
          show_usage
          exit 1
        fi
        normalized_args+=("-v" "$2")
        shift 2
        ;;
      --help)
        normalized_args+=("-h")
        shift
        ;;
      *)
        normalized_args+=("$1")
        shift
        ;;
    esac
  done

  set -- "${normalized_args[@]}"

  while getopts ":p:v:h" opt; do
    case "$opt" in
      p)
        arch="$OPTARG"
        ;;
      v)
        version="$OPTARG"
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

  shift $((OPTIND - 1))

  if [ $# -gt 0 ]; then
    log_error "get opts" "Unexpected argument: $1"
    show_usage
    exit 1
  fi
}

function download_and_move() {
  rm -rf docker-$version.tgz docker/
  log_info "print" "arch = $arch; version=$version"
  curl https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/static/stable/$arch/docker-$version.tgz -o docker-$version.tgz

  if tar -tzf "docker-$version.tgz" &>/dev/null; then
    echo "The file docker-$version.tgz is a valid tar.gz file."
  else
    echo "The file docker-$version.tgz is not a valid tar.gz file."
    exit 1
  fi

  tar zxvf docker-$version.tgz
  mv docker/* /usr/bin/
  rm -rf docker docker-$version.tgz
}

function config_systemd() {
  log_info "systemd" "config docker.service"
  curl -sSL $ROOT_URI/docker/install-manually/systemd/docker.service -o /usr/lib/systemd/system/docker.service

  log_info "systemd" "config docker.socket"
  curl -sSL $ROOT_URI/docker/install-manually/systemd/docker.socket -o /usr/lib/systemd/system/docker.socket

  log_info "systemd" "config containerd.service"
  curl -sSL $ROOT_URI/docker/install-manually/systemd/containerd.service -o /usr/lib/systemd/system/containerd.service

  log_info "systemd" "mkdir -p /etc/systemd/system/docker.service.d"
  mkdir -p /etc/systemd/system/docker.service.d
}

parse_arguments "$@"
cd /tmp
groupadd docker
download_and_move
config_systemd
systemctl daemon-reload
