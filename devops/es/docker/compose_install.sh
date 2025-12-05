#!/bin/bash
# shellcheck disable=SC1090,SC2086,SC2155,SC2128,SC2028,SC2164,SC2162
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net
source <(curl -sSL $ROOT_URI/func/log.sh)

function tips() {
  log_info "elasticsearch" "tips: prepare elasticsearch docker compose start"
  echo "--- sysctl.conf --"
  log_info "elasticsearch" "tips: vim /etc/sysctl.conf"
  echo "vm.max_map_count=262144"
  echo "sysctl -p"
  echo ""

  echo "--- limits.conf --"
  log_info "elasticsearch" "tips: vim /etc/security/limits.conf"
  echo "* soft nofile 1048576"
  echo "* hard nofile 1048576"
  echo "* soft nproc 65536"
  echo "* hard nproc 65536"
  echo "===> reboot"
  echo ""

  log_info "elasticsearch" "tips: ulimit -n 1048576 -u 65536"
  echo "ulimit -n 1048576 -u 65536"
  echo ""

  echo "--- /etc/hosts ---"
  log_info "elasticsearch" "tips: vim /etc/hosts"
  echo "192.168.0.10 node-0"
  echo "192.168.0.11 node-1"
  echo "192.168.0.12 node-2"
  echo "Modify it to what you need!!!"
  log_info "elasticsearch" "tips: prepare elasticsearch docker compose end"
}

tips

es_image=$1
container_name=$2
es_java_opts=$3

if [ -z $es_image ]; then
  es_image="elasticsearch:8.16.0"
  log_info "elasticsearch" "default es_image=$es_image"
fi

if [ -z $container_name ]; then
  container_name="elasticsearch"
  log_info "elasticsearch" "default container_name=$container_name"
fi

if [ -z $es_java_opts ]; then
  es_java_opts="-Xms6G -Xmx6G"
  log_info "elasticsearch" "default es_java_opts=$es_java_opts"
fi

current_dir=$(pwd)
log_warn "elasticsearch" "current_dir=$current_dir"
log_warn "elasticsearch" "current_dir=$current_dir"
log_warn "elasticsearch" "current_dir=$current_dir"

read -p "Confirm prepare elasticsearch's files in $current_dir [y/n]" answer

if [ "$answer" == "y" ]; then
  answer=""
  log_info "elasticsearch" "prepare elasticsearch docker compose"
else
  log_info "elasticsearch" "exit"
  exit 0
fi

function write_docker_compose_yml() {
  cat >docker-compose.yml <<EOF
services:
  elasticsearch:
    image: $es_image
    container_name: $container_name
    environment:
      - TZ=Asia/Shanghai
      - "ES_JAVA_OPTS=$es_java_opts"
    network_mode: host
    ulimits:
      memlock:
        soft: -1
        hard: -1
    user: "1000:1000"
    restart: always
    volumes:
      - "./conf/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml"
      - "./data:/usr/share/elasticsearch/data"
      - "./logs/:/usr/share/elasticsearch/logs"
      - "./cert:/usr/share/elasticsearch/config/cert"
      - "./plugins:/usr/share/elasticsearch/plugins"
EOF
}

if [ -f "docker-compose.yml" ]; then
  read -p "Do you want to rewrite it? [y/n]" answer
  if [ "$answer" == "y" ]; then
    answer=""
    log_warn "elasticsearch" "rewrite docker-compose.yml"
    write_docker_compose_yml
  else
    log_info "elasticsearch" "do not rewrite"
  fi
else
  log_info "elasticsearch" "write docker-compose.yml"
  write_docker_compose_yml
fi

function write_config_file() {
  read -p "Confirm xpack.security.transport.ssl.enabled? [y/n]" answer
  transport_ssl=""
  if [ "$answer" == "y" ]; then
    answer=""
    transport_ssl="true"
  else
    transport_ssl="false"
  fi

  function choose_node_name() {
    log_info "elasticsearch" "choose node name"
    echo "node-0 [0]"
    echo "node-1 [1]"
    echo "node-2 [2]"
    read -p "Choose node name [0/1/2]" answer
    case $answer in
    0)
      node_name="node-0"
      ;;
    1)
      node_name="node-1"
      ;;
    2)
      node_name="node-2"
      ;;
    *)
      log_warn "elasticsearch" "default node_name=node-0"
      node_name="node-0"
      ;;
    esac
  }
  choose_node_name

  cat >conf/elasticsearch.yml <<EOF
network:
  host: "$node_name"

http:
  port: 9200

node:
  name: "$node_name"
  roles: [ "master", "data" ]

discovery:
  seed_hosts:
    - "node-0"
    - "node-1"
    - "node-2"

cluster:
  name: es-cluster
  initial_master_nodes:
    - "node-0"
    - "node-1"
    - "node-2"

xpack:
  security:
    enabled: true
    http:
      ssl:
        enabled: false
    transport:
      ssl:
        enabled: $transport_ssl
        verification_mode: certificate
        client_authentication: required
        keystore:
          path: cert/elastic-certificates.p12
        truststore:
          path: cert/elastic-certificates.p12
EOF
}

if [ -d "conf" ] && [ -f "conf/elasticsearch.yml" ]; then
  log_info "elasticsearch" "conf is exist"
  log_warn "elasticsearch" "Do you want to delete config file? Will lost config data!!!"
  log_warn "elasticsearch" "Do you want to delete config file? Will lost config data!!!"
  log_warn "elasticsearch" "Do you want to delete config file? Will lost config data!!!"

  read -p "Do you want to delete config file? [y/n]" answer

  if [ "$answer" == "y" ]; then
    answer=""
    log_warn "elasticsearch" "delete config file"
    log_info "elasticsearch" "mkdir -p conf"
    rm -rf conf/
    mkdir -p conf
    log_info "elasticsearch" "chown -R 1000.1000 conf"
    write_config_file
  else
    log_info "elasticsearch" "skip delete config file"
  fi
else
  log_info "elasticsearch" "mkdir -p conf"
  rm -rf conf/
  mkdir -p conf
  log_info "elasticsearch" "chown -R 1000.1000 conf"
  write_config_file
fi

chown -R 1000.1000 conf

if [ -d "data" ] || [ -d "logs" ] || [ -d "plugins" ]; then
  log_info "elasticsearch" "data logs plugins is exist"
  log_warn "elasticsearch" "Do you want to delete them? Will lost all data!!!"
  log_warn "elasticsearch" "Do you want to delete them? Will lost all data!!!"
  log_warn "elasticsearch" "Do you want to delete them? Will lost all data!!!"
  read -p "Do you want to delete them ?[y/n]" answer
  if [ "$answer" == "y" ]; then
    answer=""
    log_warn "elasticsearch" "delete data logs plugins"
    rm -rf data logs plugins
    log_warn "elasticsearch" "mkdir -p data logs plugins"
    mkdir -p data logs plugins
    log_warn "elasticsearch" "chown -R 1000.1000 data logs plugins"
    chown -R 1000.1000 data logs plugins
  else
    log_info "elasticsearch" "exit"
    exit 0
  fi
else
  log_info "elasticsearch" "data logs plugins is not exist"
  log_warn "elasticsearch" "mkdir -p data logs plugins"
  mkdir -p data logs plugins
  log_warn "elasticsearch" "chown -R 1000.1000 data logs plugins"
  chown -R 1000.1000 data logs plugins
fi
