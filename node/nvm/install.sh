#!/bin/bash
# shellcheck disable=SC2164 disable=SC2086 disable=SC1090

[ -z "$ROOT_URI" ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL "$ROOT_URI/func/log.sh")
source <(curl -sSL "$ROOT_URI/func/command_exists.sh")

# 允许外部指定版本，默认 v0.40.1
nvm_version="${NVM_VERSION:-v0.40.1}"
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

  curl -fsSL "https://code.kubectl.net/devops/nvm/archive/$nvm_version.tar.gz" -o "$download_target_file"

  if [[ -f "$download_target_file" ]]; then
    log_info "download" "download success"
  else
    log_error "download" "download failed"
    exit 1
  fi
}

# -------------------------------
# 清理旧版本
# -------------------------------
before_clear() {
  log_info "before_clear" "remove old nvm and config"
  rm -rf "$HOME/nvm" "$HOME/.nvm" "$HOME/.npmrc"
}

# -------------------------------
# 解压 & 移动
# -------------------------------
unzip_and_move() {
  log_info "unzip" "extract nvm to $HOME"
  tar -zxf "$download_target_file" -C "$HOME"

  log_info "move" "mv $HOME/nvm $HOME/.nvm"
  mv "$HOME/nvm" "$HOME/.nvm"
}

# -------------------------------
# 配置
# -------------------------------
config_bashrc() {
  local config_file="$HOME/.bashrc"
  local nvm_nodejs_mirror="https://npmmirror.com/mirrors/node/"

  log_info "config" "update $config_file"
  sed -i '/^# NVM CONFIG START$/,/^# NVM CONFIG END$/d' "$config_file"

  cat <<EOF >>"$config_file"
# NVM CONFIG START
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export NVM_NODEJS_ORG_MIRROR=$nvm_nodejs_mirror
# NVM CONFIG END
EOF
}

config_npmrc() {
  local config_file="$HOME/.npmrc"
  log_info "config" "update $config_file"
  cat >"$config_file" <<EOF
registry=https://registry.npmmirror.com
EOF
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
