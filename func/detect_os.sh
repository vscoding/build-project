#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2028

[ -z "$ROOT_URI" ] && source <(curl -sSL https://dev.kubectl.org/init) && export ROOT_URI=$ROOT_URI
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

# 初始化变量
os_base_name=""
os_base_version=""
os_name=""
os_full_name=""

# 检测 /etc/os-release
if [ ! -f "/etc/os-release" ]; then
  echo "cannot detect os"
  exit 1
fi

# 检查 sudo
if ! command_exists sudo; then
  log "command_exists" "command sudo does not exist"
  exit 1
fi

# 加载 /etc/os-release
source /etc/os-release

# 安装 lsb-release（如果缺失）
if ! command_exists lsb_release; then
  log "detect_os" "try install lsb-release"
  case "$ID" in
    debian | ubuntu | devuan)
      sudo apt-get install -y lsb-release
      ;;
    centos | fedora | rhel)
      pkg_mgr="yum"
      if [ "$(echo "$VERSION_ID >= 22" | bc)" -ne 0 ]; then
        pkg_mgr="dnf"
      fi
      sudo "$pkg_mgr" install -y redhat-lsb-core
      ;;
    *)
      log "detect_os" "install lsb-release failed"
      exit 1
      ;;
  esac
fi

# 再次检查 lsb_release
if ! command_exists lsb_release; then
  log "command_exists" "command lsb_release does not exist"
  exit 1
fi

# 获取 OS 信息
os_base_name="$(lsb_release -si)"
os_base_version="$(lsb_release -rs | cut -d. -f1)"
os_name="${os_base_name}${os_base_version}"
os_full_name="${os_base_name}$(lsb_release -rs)"

# 循环打印日志
for var in os_base_name os_base_version os_name os_full_name; do
  log "detect_os" "$var = ${!var}"
done
