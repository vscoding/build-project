#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2155 disable=SC2128 disable=SC2028
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/command_exists.sh)

# 判断当前目录是否有docker-compose.yml文件
if [ ! -f "docker-compose.yml" ]; then
  log_error "update" "docker-compose.yml not found"
  exit 1
fi

# 判断当前目录是否有docker-compose.yaml文件
if [ ! -f "docker-compose.yaml" ]; then
  log_error "update" "docker-compose.yaml not found"
  exit 1
fi

if ! command_exists docker-compose; then
  log_error "update" "docker-compose not found, please install docker-compose first"
  exit 1
fi

log_info "update" "update docker image"
docker-compose pull

log_info "restart" "docker-compose down"
docker-compose down

log_info "restart" "docker-compose up -d"
docker-compose up -d
