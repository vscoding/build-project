#!/bin/bash
# shellcheck disable=SC1073,SC1090,SC2086,SC2155,SC2128,SC2028,SC2164,SC2162,SC2045
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)

log_warn "kafka" "install kafka three node cluster"
log_warn "kafka" "install kafka three node cluster"
log_warn "kafka" "install kafka three node cluster"

function tips() {
  log_info "kafka" "tips"
  echo "--- /etc/hosts ---"
  log_info "kafka" "tips: vim /etc/hosts"
  echo "192.168.0.10 node-0"
  echo "192.168.0.11 node-1"
  echo "192.168.0.12 node-2"
  echo "Modify it to what you need!!!"
}

tips

current_dir=$(pwd)

log_warn "kafka" "current_dir=$current_dir"
log_warn "kafka" "current_dir=$current_dir"
log_warn "kafka" "current_dir=$current_dir"

read -p "Confirm install kafka in this current directory? [y/n] :" answer
if [ "$answer" != "y" ]; then
  log_info "kafka" "exit"
  exit 0
fi

function prepare_tgz() {
  log_info "kafka" "prepare kafka tgz"

  function detect_version_by_file() {
    log_info "kafka" "detect kafka scala_version by file"

    # 正则匹配 当前目录下的文件 是否有 kafka_version.tgz scala_version 示例 kafka_2.13-3.9.0.tgz
    local pattern="kafka_([0-9]+\.[0-9]+)-([0-9]+\.[0-9]+\.[0-9]+).tgz"
    for file in $(ls); do
      if [[ $file =~ $pattern ]]; then
        scala_version=${BASH_REMATCH[1]}
        kafka_version=${BASH_REMATCH[2]}
        log_info "kafka" "scala_version=$scala_version kafka_version=$kafka_version"
        break
      fi
    done

  }
  detect_version_by_file

  if [ -z "$scala_version" ] || [ -z "$kafka_version" ]; then
    log_warn "kafka" "kafka_version or scala_version is empty"
    read -p "Choose other kafka_full_version to install: [y/n] (default n):" answer
    if [ "$answer" == "y" ]; then
      # read scala_version kafka_version
      read -p "Enter the scala_version you want to set: " scala_version
      read -p "Enter the kafka_version you want to set: " kafka_version
      if [ -z $scala_version ]; then
        scala_version="2.13"
        log_info "kafka" "default scala_version=2.13"
      fi
      if [ -z $kafka_version ]; then
        kafka_version="3.9.0"
        log_info "kafka" "default kafka_version=3.9.0"
      fi
      kafka_full_version="$scala_version-$kafka_version"
    else
      log_warn "kafka" "no kafka_full_version input"
      exit 0
    fi
  else
    kafka_full_version="$scala_version-$kafka_version"
    log_info "kafka" "kafka_full_version=$kafka_full_version"
  fi

  log_info "kafka" "scala_version=$scala_version kafka_version=$kafka_version"

  local file_name="kafka_$kafka_full_version.tgz"
  if [ -f "$file_name" ]; then
    log_info "kafka" "kafka tgz file exists"
  else
    read -p "kafka tgz file not exists, download it? [y/n] (default n):" answer
    if [ "$answer" == "y" ]; then
      local url="https://mirrors.tuna.tsinghua.edu.cn/apache/kafka/$kafka_version/kafka_$scala_version-$kafka_version.tgz"
      log_info "kafka" "wget $url"
      wget $url
      if [ ! -f $file_name ]; then
        log_warn "kafka" "wget $url failed"
        exit 1
      fi
    else
      log_info "kafka" "exit"
      exit 0
    fi
  fi

  function try_unzip() {
    if tar -tzf "$file_name" &>/dev/null; then
      log_info "kafka" "The file $file_name is a valid tar.gz file."
    else
      log_error "kafka" "The file $file_name is not a valid tar.gz file."
      exit 1
    fi

    log_info "kafka" "try unzip $file_name"
    if [ -d "kafka_$scala_version-$kafka_version" ] || [ -d "kafka" ]; then
      log_warn "kafka" "kafka_$scala_version-$kafka_version or kafka directory exists"
      log_warn "kafka" "Are you sure to delete it? It will delete all data in it."
      log_warn "kafka" "Are you sure to delete it? It will delete all data in it."
      log_warn "kafka" "Are you sure to delete it? It will delete all data in it."
      read -p "Are you sure to delete it? [y/n] (default n):" answer
      if [ "$answer" == "y" ]; then
        log_warn "kafka" "delete kafka_$scala_version-$kafka_version or kafka directory"
        log_warn "kafka" "rm -rf kafka_$scala_version-$kafka_version"
        rm -rf kafka_$scala_version-$kafka_version
        log_warn "kafka" "rm -rf kafka"
        rm -rf kafka
        log_warn "kafka" "tar -zxvf $file_name"
        tar -zxvf $file_name
      else
        log_info "kafka" "exit"
        exit 0
      fi
    else
      log_warn "kafka" "tar -zxvf $file_name"
      tar -zxvf $file_name
    fi

  }
  try_unzip

  log_info "kafka" "mv kafka_$scala_version-$kafka_version kafka"
  mv kafka_$scala_version-$kafka_version kafka
}

prepare_tgz

function config_properties() {
  log_info "kafka" "config kafka kraft properties"

  local kraft_server_properties="kafka/config/kraft/server.properties"

  if [ ! -f "$kraft_server_properties" ]; then
    log_error "kafka" "$kraft_server_properties is not exist"
    exit 1
  else
    log_info "kafka" "$kraft_server_properties is exist"
    local backup_file="$kraft_server_properties.$(date +%Y%m%d%H%M%S)"
    log_info "kafka" "backup $kraft_server_properties to $backup_file"
    cp $kraft_server_properties $backup_file
  fi

  # read kafka cluster name
  log_info "kafka" "Enter the cluster name you want to set: [e.g. kafka-cluster]"
  read -p "Enter the cluster name you want to set (default kafka-cluster):" cluster_name
  if [ -z $cluster_name ]; then
    cluster_name="kafka-cluster"
    log_info "kafka" "default cluster_name=kafka-cluster"
  fi

  function read_three_node_ip() {
    # function validate ipv4
    function validate_ipv4() {
      local ip=$1
      if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_info "kafka" "validate ipv4 success"
        return 0
      else
        log_warn "kafka" "validate ipv4 failed"
        return 1
      fi
    }

    function read_node0_ip() {
      log_info "kafka" "Enter the node-0 ip you want to set"
      read -p "Enter the node-0 ip you want to set: " node_0_ip
      if validate_ipv4 $node_0_ip; then
        log_info "kafka" "node-0 ip=$node_0_ip"
      else
        log_warn "kafka" "node-0 ip is invalid"
        read_node0_ip
      fi
    }

    function read_node1_ip() {
      log_info "kafka" "Enter the node-1 ip you want to set"
      read -p "Enter the node-1 ip you want to set: " node_1_ip
      if validate_ipv4 $node_1_ip; then
        log_info "kafka" "node-1 ip=$node_1_ip"
      else
        log_warn "kafka" "node-1 ip is invalid"
        read_node1_ip
      fi
    }

    function read_node2_ip() {
      log_info "kafka" "Enter the node-2 ip you want to set"
      read -p "Enter the node-2 ip you want to set: " node_2_ip
      if validate_ipv4 $node_2_ip; then
        log_info "kafka" "node-2 ip=$node_2_ip"
      else
        log_warn "kafka" "node-2 ip is invalid"
        read_node2_ip
      fi
    }

    read_node0_ip
    read_node1_ip
    read_node2_ip

    log_info "kafka" "node-0 ip=$node_0_ip"
    log_info "kafka" "node-1 ip=$node_1_ip"
    log_info "kafka" "node-2 ip=$node_2_ip"

    # 三个 ip 都不为空
    if [ -z $node_0_ip ] || [ -z $node_1_ip ] || [ -z $node_2_ip ]; then
      log_warn "kafka" "node_0_ip or node_1_ip or node_2_ip is empty"
      read_three_node_ip
    fi
  }

  function read_broker_id() {
    read -p "Enter the broker.id  you want to set [0/1/2] :" broker_id
    case $broker_id in
    0)
      log_info "kafka" "broker.id=0"
      node_ip=$node_0_ip
      ;;
    1)
      log_info "kafka" "broker.id=1"
      node_ip=$node_1_ip
      ;;
    2)
      log_info "kafka" "broker.id=2"
      node_ip=$node_2_ip
      ;;
    *)
      read_broker_id
      ;;
    esac
  }

  read_three_node_ip
  read_broker_id

  function prepare_logs_dir() {
    log_info "kafka" "Enter the log.dirs you want to set: [e.g. /tmp/kafka-logs]"
    read -p "Enter the log.dirs you want to set: (default /data/persistence/kafka)" log_dirs
    if [ -z $log_dirs ]; then
      log_dirs="/data/persistence/kafka"
    fi

    if [ -d $log_dirs ]; then
      log_info "kafka" "$log_dirs exists"
      log_warn "kafka" "Are you sure to delete it? It will delete all data in it."
      log_warn "kafka" "Are you sure to delete it? It will delete all data in it."
      log_warn "kafka" "Are you sure to delete it? It will delete all data in it."
      read -p "Are you sure to delete it? [y/n] :" answer
      if [ "$answer" == "y" ]; then
        log_warn "kafka" "rm -rf $log_dirs"
        rm -rf $log_dirs
        log_info "kafka" "mkdir -p $log_dirs"
        mkdir -p $log_dirs
      else
        log_info "kafka" "skip clear $log_dirs"
      fi
    else
      log_info "kafka" "mkdir -p $log_dirs"
      mkdir -p $log_dirs
    fi
  }

  prepare_logs_dir

  log_info "kafka" "config kafka kraft properties"

  local internal_port=9094
  local controller_port=9093
  local client_port=9092
  log_info "kafka" "internal_port=$internal_port controller_port=$controller_port client_port=$client_port"

  cat >$kraft_server_properties <<EOF
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# This configuration file is intended for use in ZK-based mode, where Apache ZooKeeper is required.
# See kafka.server.KafkaConfig for additional details and defaults
#

############################# Server Basics #############################

# The id of the broker. This must be set to a unique integer for each broker.
process.roles=broker,controller

broker.id=$broker_id

controller.quorum.voters=0@$node_0_ip:$controller_port,1@$node_1_ip:$controller_port,2@$node_2_ip:$controller_port

############################# Socket Server Settings #############################

# The address the socket server listens on. If not configured, the host name will be equal to the value of
# java.net.InetAddress.getCanonicalHostName(), with PLAINTEXT listener name, and port 9092.
#   FORMAT:
#     listeners = listener_name://host_name:port
#   EXAMPLE:
#     listeners = PLAINTEXT://your.host.name:9092
#listeners=PLAINTEXT://:9092

listeners=PLAINTEXT://$node_ip:$internal_port,CONTROLLER://$node_ip:$controller_port,CLIENT://$node_ip:$client_port

inter.broker.listener.name=PLAINTEXT

# Modify yourself
advertised.listeners=PLAINTEXT://$node_ip:$internal_port,CLIENT://${cluster_name}-$broker_id:$client_port

controller.listener.names=CONTROLLER

# Maps listener names to security protocols, the default is for them to be the same. See the config documentation for more details
#listener.security.protocol.map=PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT,CLIENT:PLAINTEXT

# The number of threads that the server uses for receiving requests from the network and sending responses to the network
num.network.threads=3

# The number of threads that the server uses for processing requests, which may include disk I/O
num.io.threads=8

# The send buffer (SO_SNDBUF) used by the socket server
socket.send.buffer.bytes=102400

# The receive buffer (SO_RCVBUF) used by the socket server
socket.receive.buffer.bytes=102400

# The maximum size of a request that the socket server will accept (protection against OOM)
socket.request.max.bytes=104857600

############################# Log Basics #############################

# A comma separated list of directories under which to store log files
log.dirs=$log_dirs

# The default number of log partitions per topic. More partitions allow greater
# parallelism for consumption, but this will also result in more files across
# the brokers.
num.partitions=1

# The number of threads per data directory to be used for log recovery at startup and flushing at shutdown.
# This value is recommended to be increased for installations with data dirs located in RAID array.
num.recovery.threads.per.data.dir=1

############################# Internal Topic Settings  #############################
# The replication factor for the group metadata internal topics "__consumer_offsets" and "__transaction_state"
# For anything other than development testing, a value greater than 1 is recommended to ensure availability such as 3.
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=3

############################# Log Flush Policy #############################

# Messages are immediately written to the filesystem but by default we only fsync() to sync
# the OS cache lazily. The following configurations control the flush of data to disk.
# There are a few important trade-offs here:
#    1. Durability: Unflushed data may be lost if you are not using replication.
#    2. Latency: Very large flush intervals may lead to latency spikes when the flush does occur as there will be a lot of data to flush.
#    3. Throughput: The flush is generally the most expensive operation, and a small flush interval may lead to excessive seeks.
# The settings below allow one to configure the flush policy to flush data after a period of time or
# every N messages (or both). This can be done globally and overridden on a per-topic basis.

# The number of messages to accept before forcing a flush of data to disk
#log.flush.interval.messages=10000

# The maximum amount of time a message can sit in a log before we force a flush
#log.flush.interval.ms=1000

############################# Log Retention Policy #############################

# The following configurations control the disposal of log segments. The policy can
# be set to delete segments after a period of time, or after a given size has accumulated.
# A segment will be deleted whenever *either* of these criteria are met. Deletion always happens
# from the end of the log.

# The minimum age of a log file to be eligible for deletion due to age
log.retention.hours=168

# A size-based retention policy for logs. Segments are pruned from the log unless the remaining
# segments drop below log.retention.bytes. Functions independently of log.retention.hours.
#log.retention.bytes=1073741824

# The maximum size of a log segment file. When this size is reached a new log segment will be created.
#log.segment.bytes=1073741824

# The interval at which log segments are checked to see if they can be deleted according
# to the retention policies
log.retention.check.interval.ms=300000

EOF

  function create_reinit_sh() {
    log_info "elasticsearch" "create reinit.sh"
    cat >kafka/reinit.sh <<EOF
#!/bin/bash
# shellcheck disable=SC2164
SHELL_FOLDER=\$(cd "\$(dirname "\$0")" && pwd)
cd "\$SHELL_FOLDER"

function read_uuid(){
  read -p "Input uuid :" uuid
  if [ -z \$uuid ]; then
    echo "uuid is empty,retry"
    read_uuid
  fi
}
read_uuid

echo "clear logs directory"
rm -rf logs/

echo "mkdir logs directory"
mkdir -p logs/

echo "clear logs directory"
rm -rf $log_dirs
mkdir -p $log_dirs

bin/kafka-storage.sh format -t \$uuid -c config/kraft/server.properties

EOF
  }

  function create_start_sh() {
    cat >kafka/start.sh <<EOF
#!/bin/bash
# shellcheck disable=SC2164
SHELL_FOLDER=\$(cd "\$(dirname "\$0")" && pwd)
cd "\$SHELL_FOLDER"
echo "start kafka"
bin/kafka-server-start.sh config/kraft/server.properties
EOF
  }

  function create_describe_sh() {
    log_info "kafka" "create describe.sh"
    cat >kafka/describe.sh <<EOF
#!/bin/bash
# shellcheck disable=SC2164
SHELL_FOLDER=\$(cd "\$(dirname "\$0")" && pwd)
cd "\$SHELL_FOLDER"

echo "bin/kafka-metadata-quorum.sh --bootstrap-server $node_0_ip:$internal_port,$node_1_ip:$internal_port,$node_2_ip:$internal_port describe --replication"
bin/kafka-metadata-quorum.sh --bootstrap-server $node_0_ip:$internal_port,$node_1_ip:$internal_port,$node_2_ip:$internal_port describe --replication

echo "bin/kafka-metadata-quorum.sh --bootstrap-server $node_0_ip:$internal_port,$node_1_ip:$internal_port,$node_2_ip:$internal_port describe --status"
bin/kafka-metadata-quorum.sh --bootstrap-server $node_0_ip:$internal_port,$node_1_ip:9094,$node_2_ip:$internal_port describe --status
EOF
  }

  create_reinit_sh
  create_start_sh
  create_describe_sh

  function try_soft_link() {
    log_info "kafka" "try soft link $log_dirs to kafka/data"
    # 判断 $path_data_logs 是否不以 $current_dir/elasticsearch 开头
    if [[ $log_dirs != $current_dir/kafka* ]]; then
      log_warn "kafka" "soft link $log_dirs to kafka/data"
      ln -s $log_dirs kafka/data
    fi
  }
  try_soft_link
}

config_properties

function format_kafka_logs_dir() {
  log_info "kafka" "format kafka logs dir"
  read -p "Are you sure to format kafka logs dir? [y/n] (default n):" answer
  if [ "$answer" == "y" ]; then
    read -p "Are you sure generate random-uuid? [y/n] (default n):" answer
    if [ "$answer" == "y" ]; then
      log_info "kafka" "generate random-uuid"

      if [ -f "kafka/bin/kafka-storage.sh" ]; then
        uuid=$(kafka/bin/kafka-storage.sh random-uuid)
        log_info "kafka" "uuid=$uuid"
      else
        log_error "kafka" "kafka/bin/kafka-storage.sh is not exist"
        exit 1
      fi

      log_info "kafka" "kafka-storage.sh format -t $uuid -c $kraft_server_properties"
      kafka/bin/kafka-storage.sh format -t $uuid -c $kraft_server_properties

    else
      read -p "Enter the uuid you want to set: " uuid
      if [ -z $uuid ]; then
        log_warn "kafka" "uuid is empty"
        exit 1
      fi
      log_info "kafka" "kafka-storage.sh format -t $uuid -c $kraft_server_properties"
      kafka/bin/kafka-storage.sh format -t $uuid -c $kraft_server_properties
    fi

  else
    log_info "kafka" "skip format kafka logs dir"
  fi

}

format_kafka_logs_dir

function create_systemd() {
  log_info "kafka" "create /usr/lib/systemd/system/kafka.service"

  function read_java_home() {
    if [ -z $JAVA_HOME ]; then
      log_warn "kafka" "JAVA_HOME is empty"
      read -p "Enter the JAVA_HOME you want to set: " JAVA_HOME
      if [ -z $JAVA_HOME ]; then
        log_warn "kafka" "JAVA_HOME is empty"
        read_java_home
      else
        log_info "kafka" "JAVA_HOME=$JAVA_HOME"
        if [ ! -f "$JAVA_HOME/bin/java" ]; then
          log_warn "kafka" "java is not exist"
          read_java_home
        else
          log_info "kafka" "java is exist"
          $JAVA_HOME/bin/java -version
        fi
      fi
    else
      log_info "kafka" "JAVA_HOME=$JAVA_HOME"
    fi
  }
  read_java_home

  function read_java_options() {
    read -p "Enter the JAVA_OPTS you want to set. [default -Xmx2G -Xms2G] :" JAVA_OPTS
    if [ -z $JAVA_OPTS ]; then
      JAVA_OPTS="-Xmx2G -Xms2G"
      log_info "kafka" "default JAVA_OPTS=$JAVA_OPTS"
    fi
  }
  read_java_options

  cat >/usr/lib/systemd/system/kafka.service <<EOF
[Unit]
Description=Apache Kafka server (broker)
Documentation=http://kafka.apache.org/documentation.html
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=simple
User=root
Group=root
Restart=on-failure
RestartSec=5
Environment=JAVA_HOME=$JAVA_HOME
Environment=KAFKA_HEAP_OPTS=$JAVA_OPTS
WorkingDirectory=$current_dir/kafka
ExecStart=$current_dir/kafka/bin/kafka-server-start.sh $current_dir/kafka/config/kraft/server.properties
ExecStop=$current_dir/kafka/bin/kafka-server-stop.sh

[Install]
WantedBy=multi-user.target
EOF
  log_warn "kafka" "systemctl daemon-reload"
  systemctl daemon-reload
}

create_systemd
