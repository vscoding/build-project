#!/bin/bash
# shellcheck disable=SC1090,SC2086,SC2155,SC2128,SC2028,SC2164,SC2162
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)

log_warn "elasticsearch" "install elasticsearch Three node cluster"
log_warn "elasticsearch" "install elasticsearch Three node cluster"
log_warn "elasticsearch" "install elasticsearch Three node cluster"

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

current_dir=$(pwd)

log_warn "elasticsearch" "current_dir=$current_dir"
log_warn "elasticsearch" "current_dir=$current_dir"
log_warn "elasticsearch" "current_dir=$current_dir"

read -p "Confirm install elasticsearch in this current directory? [y/n] :" answer
if [ "$answer" != "y" ]; then
  log_info "elasticsearch" "exit"
  exit 0
fi

function prepare_tar_gz() {
  log_info "elasticsearch" "prepare tar.gz"

  function detect_version_by_file() {
    log_info "elasticsearch" "detect version by file"
    # 正则匹配 当前目录的文件是否有 elasticsearch-version-linux-x86_64.tar.gz
    local pattern="elasticsearch-([0-9]+\.[0-9]+\.[0-9]+)-linux-x86_64.tar.gz"
    for file in $(ls); do
      if [[ $file =~ $pattern ]]; then
        version=${BASH_REMATCH[1]}
        break
      fi
    done
    log_info "elasticsearch" "detect version=$version"
  }
  detect_version_by_file

  if [ -z $version ]; then
    read -p "Choose other version to install: [y/n] :" answer
    if [ "$answer" == "y" ]; then
      read -p "Enter the version of elasticsearch you want to install: " version
      if [ -z $version ]; then
        version="8.16.0"
      fi
    fi
  fi

  log_info "elasticsearch" "version=$version"

  local file_name="elasticsearch-$version-linux-x86_64.tar.gz"

  if [ -f "$file_name" ]; then
    log_info "elasticsearch" "$file_name is exist"
  else
    read -p "Are you sure you want to download from the Internet? [y/n] :" download
    if [ "$download" != "y" ]; then
      log_info "elasticsearch" "exit"
      exit 0
    fi
    log_info "elasticsearch" "$file_name is not exist"
    log_info "elasticsearch" "download $file_name"
    wget https://artifacts.elastic.co/downloads/elasticsearch/$file_name

    if [ ! -f $file_name ]; then
      log_warn "elasticsearch" "wget https://artifacts.elastic.co/downloads/elasticsearch/$file_name failed"
      exit 1
    fi

  fi

  function try_unzip() {

    if tar -tzf "$file_name" &>/dev/null; then
      log_info "elasticsearch" "The file $file_name is a valid tar.gz file."
    else
      log_error "elasticsearch" "The file $file_name is not a valid tar.gz file."
      exit 1
    fi

    log_info "elasticsearch" "try unzip $file_name"
    if [ -d "elasticsearch-$version" ] || [ -d "elasticsearch" ]; then
      log_warn "elasticsearch" "elasticsearch-$version or elasticsearch is exist"
      log_warn "elasticsearch" "Are you sure you want to unzip again? It will delete the existing directory elasticsearch-$version/ and elasticsearch/ "
      log_warn "elasticsearch" "Are you sure you want to unzip again? It will delete the existing directory elasticsearch-$version/ and elasticsearch/ "
      log_warn "elasticsearch" "Are you sure you want to unzip again? It will delete the existing directory elasticsearch-$version/ and elasticsearch/ "
      read -p "Are you sure you want to unzip again? [y/n] :" unzip
      if [ "$unzip" != "y" ]; then
        log_info "elasticsearch" "exit"
        exit 0
      else
        log_info "elasticsearch" "rm -rf elasticsearch-$version"
        rm -rf elasticsearch-$version
        log_info "elasticsearch" "rm -rf elasticsearch"
        rm -rf elasticsearch
        log_info "elasticsearch" "tar -zxvf $file_name"
        tar -zxvf $file_name
      fi
    else
      log_info "elasticsearch" "tar -zxvf $file_name"
      tar -zxvf $file_name
    fi
  }
  try_unzip

  function rename_folders() {
    log_info "elasticsearch" "mv elasticsearch-$version elasticsearch"
    mv elasticsearch-$version elasticsearch
  }
  rename_folders
}

prepare_tar_gz

function create_user() {
  log_info "elasticsearch" "create user"
  read -p "Enter the user name you want to create (default is es) :" user_name

  if [ -z $use_name ]; then
    user_name="es"
    log_info "elasticsearch" "default user_name=$user_name"
  fi

  if id -u $user_name &>/dev/null; then
    log_info "elasticsearch" "user $user_name is exist"
  else
    log_info "elasticsearch" "user $user_name is not exist"
    log_info "elasticsearch" "create user $user_name"
    # useradd -M $user_name
    # 当您使用命令如`useradd`创建新用户时，系统通常会：
    # 1. 创建一个新的用户账户。
    # 2. 创建一个新的用户组（如果没有指定`-N`选项）。
    useradd -M -r -s /sbin/nologin $user_name
  fi
}
create_user

function prepare_es_env() {
  log_info "elasticsearch" "prepare elasticsearch's environment"

  function set_jvm_options() {
    log_info "elasticsearch" "jvm.options"
    read -p "Enter the jvm.options (-Xms) you want to set: (default: -Xms4g) :" jvm_options_xms
    read -p "Enter the jvm.options (-Xmx) you want to set: (default: -Xmx4g) :" jvm_options_xmx

    if [ -z $jvm_options_xms ]; then
      jvm_options_xms="-Xms4g"
      log_info "elasticsearch" "default jvm_options (-Xms) $jvm_options_xms"
    fi

    if [ -z $jvm_options_xmx ]; then
      jvm_options_xmx="-Xmx4g"
      log_info "elasticsearch" "default jvm_options (-Xmx) =$jvm_options_xmx"
    fi

    if [ -d "elasticsearch/config/jvm.options.d" ]; then
      log_info "elasticsearch" "elasticsearch/config/jvm.options.d is exist"
      log_info "elasticsearch" "echo $jvm_options_xms > elasticsearch/jvm.options.d/jvm.options"
      log_info "elasticsearch" "echo $jvm_options_xmx >> elasticsearch/jvm.options.d/jvm.options"
      # https://www.elastic.co/guide/en/elasticsearch/reference/current/advanced-configuration.html
      # https://discuss.elastic.co/t/invalid-initial-heap-size/143248/7
      echo "$jvm_options_xms" >elasticsearch/config/jvm.options.d/jvm.options
      echo "$jvm_options_xmx" >>elasticsearch/config/jvm.options.d/jvm.options
    else
      log_error "elasticsearch" "elasticsearch/jvm.options.d is not exist"
      exit 1
    fi

  }

  function config_yml() {
    log_info "elasticsearch" "config elasticsearch.yml"

    if [ ! -f "elasticsearch/config/elasticsearch.yml" ]; then
      log_error "elasticsearch" "elasticsearch/config/elasticsearch.yml is not exist"
      exit 1
    else
      log_info "elasticsearch" "elasticsearch/config/elasticsearch.yml is exist"
      local backup_file="elasticsearch/config/elasticsearch.yml.$(date +%Y%m%d%H%M%S)"
      log_info "elasticsearch" "cp elasticsearch/config/elasticsearch.yml $backup_file"
      cp elasticsearch/config/elasticsearch.yml $backup_file
    fi

    read -p "Enter the cluster name you want to set: (default: es-cluster) :" cluster_name
    if [ -z $cluster_name ]; then
      cluster_name="es-cluster"
      log_info "elasticsearch" "default cluster_name=$cluster_name"
    fi

    log_info "elasticsearch" "Enter the node name you want to set: [0] node-0"
    log_info "elasticsearch" "Enter the node name you want to set: [1] node-1"
    log_info "elasticsearch" "Enter the node name you want to set: [2] node-2"
    read -p "Enter the node name you want to set: (default: [0] node-0) :" node_name
    case $node_name in
    0 | node-0)
      node_name="node-0"
      ;;
    1 | node-1)
      node_name="node-1"
      ;;
    2 | node-2)
      node_name="node-2"
      ;;
    *)
      log_warn "elasticsearch" "default node_name=node-0"
      node_name="node-0"
      ;;
    esac

    read -p "Confirm xpack.security.transport.ssl.enabled? [y/n] :" xpack_security_transport_ssl_enabled

    function try_use_local_cert() {
      if [ -f "cert.tar.gz" ]; then
        log_info "elasticsearch" "cert.tar.gz is exist"
        log_info "elasticsearch" "tar -zxvf cert.tar.gz -C elasticsearch/config"
        tar -zxvf cert.tar.gz -C elasticsearch/config
      else
        log_warn "elasticsearch" "xpack.security.transport.ssl.enabled: true"
        log_warn "elasticsearch" "should prepare ca & cert "
        log_warn "elasticsearch" "Should prepare ca & cert"
        log_warn "elasticsearch" "Should prepare ca & cert"
      fi
    }

    if [ $xpack_security_transport_ssl_enabled == "y" ]; then
      xpack_security_transport_ssl_enabled="true"
      try_use_local_cert
    else
      xpack_security_transport_ssl_enabled="false"
    fi

    read -p "Input basic path for data & log: (default: /data/persistence/elasticsearch) :" path_data_logs
    if [ -z $path_data_logs ]; then
      path_data_logs="/data/persistence/elasticsearch"
      log_info "elasticsearch" "default path_data_logs=$path_data_logs"
    fi

    if [ -d $path_data_logs ]; then
      log_warn "elasticsearch" "$path_data_logs is exist, it can be deleted.All data will be lost!!!"
      log_warn "elasticsearch" "$path_data_logs is exist, it can be deleted.All data will be lost!!!"
      log_warn "elasticsearch" "$path_data_logs is exist, it can be deleted.All data will be lost!!!"
      read -p "Do you want to delete it? [y/n] :" answer
      if [ $answer == "y" ]; then
        log_warn "elasticsearch" "clean it rm -rf $path_data_logs"
        rm -rf $path_data_logs
        log_warn "elasticsearch" "mkdir -p $path_data_logs/{data,logs}"
        mkdir -p $path_data_logs/{data,logs}
      fi
    else
      log_info "elasticsearch" "mkdir -p $path_data_logs/{data,logs}"
      mkdir -p $path_data_logs/{data,logs}
    fi

    function create_reinit_sh() {
      log_info "elasticsearch" "create reinit.sh"
      cat >elasticsearch/reinit.sh <<EOF
#!/bin/bash
# shellcheck disable=SC2164
SHELL_FOLDER=\$(cd "\$(dirname "\$0")" && pwd)
cd "\$SHELL_FOLDER"

echo "clear gc logs"
rm -rf logs/*

echo "clear es data"
rm -rf $path_data_logs/data/*

echo "clear es logs"
rm -rf $path_data_logs/logs/*
EOF
    }

    create_reinit_sh

    log_info "elasticsearch" "cluster.name: $cluster_name"
    log_info "elasticsearch" "node.name: $node_name"
    log_info "elasticsearch" "xpack.security.transport.ssl.enabled: $xpack_security_transport_ssl_enabled"
    cat >elasticsearch/config/elasticsearch.yml <<EOF
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
  name: $cluster_name
  initial_master_nodes:
    - "node-0"
    - "node-1"
    - "node-2"

path:
  data:
    - $path_data_logs/data
  logs: $path_data_logs/logs

xpack:
  security:
    enabled: true
    http:
      ssl:
        enabled: false
    transport:
      ssl:
        enabled: $xpack_security_transport_ssl_enabled
        verification_mode: certificate
        client_authentication: required
        keystore:
          path: cert/elastic-certificates.p12
        truststore:
          path: cert/elastic-certificates.p12
EOF

  }

  function try_soft_link() {
    # 判断 $path_data_logs 是否不以 $current_dir/elasticsearch 开头
    if [[ $path_data_logs != $current_dir/elasticsearch* ]]; then
      log_info "elasticsearch" "$path_data_logs is start with $current_dir/elasticsearch"
      log_info "elasticsearch" "ln -s $path_data_logs elasticsearch/data"
      ln -s $path_data_logs elasticsearch/data
    fi
  }

  set_jvm_options
  config_yml
  try_soft_link

  log_info "elasticsearch" "chown -R $user_name:$user_name elasticsearch $path_data_logs"
  chown -R $user_name:$user_name elasticsearch $path_data_logs
}

prepare_es_env

function create_systemd() {
  log_info "elasticsearch" "create elasticsearch.service version=$version"
  cat >/usr/lib/systemd/system/elasticsearch.service <<EOF
[Unit]
Description=Elasticsearch $version
Documentation=https://www.elastic.co
Wants=network-online.target
After=network-online.target

[Service]
User=es
Group=es

WorkingDirectory=$current_dir/elasticsearch

ExecStart=$current_dir/elasticsearch/bin/elasticsearch -p $current_dir/elasticsearch/elasticsearch.pid

Restart=always
LimitNOFILE=65536
LimitMEMLOCK=infinity
TimeoutStopSec=0
KillSignal=SIGTERM
SendSIGKILL=no
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
}

create_systemd
