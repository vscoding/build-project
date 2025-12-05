#!/bin/bash
# shellcheck disable=SC1090,SC2086,SC2155,SC2128,SC2028,SC2164,SC2162
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/command_exists.sh)

log_info "elasticsearch" "create ca and cert"

log_info "elasticsearch" "step 1 prepare"

current_dir=$(pwd)
log_info "elasticsearch" "current_dir=$current_dir"

target_dir="$current_dir/cert"

function prepare() {
  if ! command_exists docker; then
    log_error "elasticsearch" "docker is not installed"
    exit 1
  fi

  if [ -d $target_dir ]; then
    log_info "elasticsearch" "$target_dir is exist"
    read -p "Do you want to delete it? [y/n]" answer
    if [ "$answer" == "y" ]; then
      log_warn "elasticsearch" "delete it rm -rf $target_dir"
      rm -rf $target_dir
      log_warn "elasticsearch" "delete cert.tar.gz"
      rm -rf cert.tar.gz
      mkdir -p $target_dir
    else
      log_info "elasticsearch" "exit"
      exit 0
    fi
  else
    log_info "elasticsearch" "$target_dir is not exist"
    log_info "elasticsearch" "create it mkdir -p $target_dir"
    log_warn "elasticsearch" "delete cert.tar.gz"
    rm -rf cert.tar.gz
    mkdir -p $target_dir
  fi

  chown -R 1000.1000 $target_dir
}

log_info "elasticsearch" "target_dir is $target_dir"

prepare

es_image=$1
ca_filename=$2
cert_filename=$3

if [ -z $es_image ]; then
  es_image=elasticsearch:8.16.0
fi

if [ -z $ca_filename ]; then
  ca_filename=elastic-stack-ca.p12
fi

if [ -z $cert_file_nam ]; then
  cert_filename=elastic-certificates.p12
fi

log_info "elasticsearch" "step 2 create ca"

docker run --rm -it -v $target_dir:/usr/share/elasticsearch/config/cert \
  --user 1000:1000 \
  $es_image \
  bin/elasticsearch-certutil ca --days 3650 -out config/cert/$ca_filename

if [ -f $target_dir/$ca_filename ]; then
  log_info "elasticsearch" "create ca success"
else
  log_error "elasticsearch" "create ca failed"
  exit 1
fi

log_info "elasticsearch" "step 3 create cert"

docker run --rm -it \
  --user 1000:1000 \
  -v $target_dir:/usr/share/elasticsearch/config/cert \
  $es_image \
  bin/elasticsearch-certutil cert --ca config/cert/$ca_filename --days 3650 -out config/cert/$cert_filename

if [ -f $target_dir/$cert_filename ]; then
  log_info "elasticsearch" "create cert success"
else
  log_error "elasticsearch" "create cert failed"
  exit 1
fi

log_info "elasticsearch" "step 4 tar cert"

tar -zcvf cert.tar.gz cert/$cert_filename
