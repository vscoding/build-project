#!/usr/bin/env bash
# shellcheck disable=SC2164 disable=SC2086 disable=SC1090

[ -z "$ROOT_URI" ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

nvm_version="v0.40.8"
download_target_file="/tmp/nvm_$nvm_version.tar.gz"

log_info "install" "start install nvm by root user, version=$nvm_version"

# -------------------------------
# 前置检查
# -------------------------------
prepare() {
  if ! command_exists curl; then
    log_error "prepare" "command curl does not exist"
    exit 1
  fi
}
prepare

# -------------------------------
# 下载
# -------------------------------
download() {
  rm -f "$download_target_file"

  curl -X POST https://ctrl.kubectl.org/api/relay \
    -H "Content-Type: application/json" \
    -d "{\"url\":\"https://github.com/nvm-sh/nvm/archive/refs/tags/${nvm_version}.tar.gz\",\"headers\":{}}" \
    -o "$download_target_file"

  if [[ ! -s "$download_target_file" ]]; then
    log_error "download" "download failed"
    exit 1
  fi
  log_info "download" "download success"
}

# -------------------------------
# 清理旧版本
# -------------------------------
before_clear() {
  log_info "before_clear" "remove old nvm and config"
  rm -rf "$HOME/nvm*" "$HOME/.nvm" "$HOME/.npmrc"
}

# -------------------------------
# 解压 & 移动
# -------------------------------
unzip_and_move() {
  log_info "unzip" "extract nvm to $HOME"
  if ! tar -zxf "$download_target_file" -C "$HOME"; then
    log_error "unzip" "failed to extract $download_target_file"
    exit 1
  fi
  log_info "move" "mv $HOME/nvm $HOME/.nvm"
  # 解压后的文件是  nvm-版本号，移动到 .nvm
  mv "$HOME/nvm-"* "$HOME/.nvm"
}

# -------------------------------
# 配置
# -------------------------------
config_bashrc() {
  local config_file="$HOME/.bashrc"

  log_info "config" "update $config_file"
  sed -i '/^# NVM CONFIG START$/,/^# NVM CONFIG END$/d' "$config_file"

  printf '%s\n' '# NVM CONFIG START
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node/
# NVM CONFIG END' >>"$config_file"
}

config_npmrc() {
  local config_file="$HOME/.npmrc"
  log_info "config" "update $config_file"
  printf '%s\n' 'registry=https://registry.npmmirror.com' >"$config_file"
}

# -------------------------------
# 清理下载包
# -------------------------------
download_clear() {
  log_info "clear" "remove $download_target_file"
  rm -f "$download_target_file"
}

# -------------------------------
# 主流程
# -------------------------------
main() {
  download
  before_clear
  unzip_and_move
  config_bashrc
  config_npmrc
  download_clear
  log_info "install" "nvm installation completed"
}

main "$@"
