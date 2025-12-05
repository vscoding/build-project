#!/bin/bash
# shellcheck disable=SC1090,SC2155,SC2086,SC2154
set -euo pipefail
IFS=$'\n\t'

[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

OS=""

# 检测操作系统
function detect_os() {
  source <(curl -sSL "$ROOT_URI/func/detect_os.sh")
  case "$os_name" in
    *Ubuntu*) OS="ubuntu" ;;
    *Debian*) OS="debian" ;;
    *) OS="unknown" ;;
  esac
}

# 安装源提示
function tips() {
  log_info "tips" "SRC 参数为脚本的安装源:"
  log_info "tips" "可选: docker(官方源), tsinghua(清华源), aliyun(阿里云), intellij(镜像)"
  log_info "tips" "示例: bash <(curl -sSL $ROOT_URI/docker/install/i.sh) tsinghua"
}

# 检查 docker 是否已安装
function check_docker_exists() {
  if command_exists docker; then
    log_warn "docker" "系统已存在 docker 命令"
    log_warn "如果你已安装 Docker，本脚本可能导致冲突。"
    log_warn "如果你是用本脚本安装的 Docker 并再次运行更新，可忽略此提示。"
    exit 0
  fi
}

# 执行安装
function do_install() {
  local src="${1:-}"
  if [[ "$OS" =~ ^(debian|ubuntu)$ ]]; then
    case "$src" in
      docker | tsinghua | aliyun | intellij)
        log_info "install" "当前系统: $OS, 选择安装源: $src"
        bash <(curl -sSL "$ROOT_URI/docker/install/$OS/install_${src}.sh")
        ;;
      *)
        tips
        exit 1
        ;;
    esac
  else
    log_warn "install" "当前仅支持 Debian 与 Ubuntu"
    tips
    exit 1
  fi
}

# 配置 docker systemd
function config_docker() {
  if command_exists systemctl; then
    log_info "config" "systemctl enable docker"
    systemctl enable docker
    log_info "config" "docker 服务状态: $(systemctl is-enabled docker || echo 'not enabled')"
  else
    log_warn "config" "systemctl 不存在，跳过 docker 开机自启配置"
  fi
}

# 主流程
detect_os
check_docker_exists
SRC="${1:-}"
[[ -z "$SRC" ]] && {
  tips
  exit 1
}
do_install "$SRC"
config_docker
