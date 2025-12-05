#!/bin/bash
# shellcheck disable=SC1090 disable=SC2164 disable=SC2126  disable=SC2086 disable=SC2028
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/command_exists.sh)

function verify_nginx_configuration() {
  log_info "nginx" "Verify the nginx configuration file that docker-compose starts"

  local docker_in_docker="false"
  if ! command_exists docker; then
    log_error "nginx" "docker command does not exits"
    return 1
  elif docker compose 2>&1 | grep -q "^docker: 'compose' is not a docker command."; then
    log_warn "nginx" "docker: 'compose' is not a docker command."
    log_warn "nginx" "use docker in docker"
    docker_in_docker="true"
  fi

  local compose_file=$2
  local service_name=$1

  if [ -z "$compose_file" ]; then
    log_info "nginx" "compose file is empty, try use docker-compose.yml or docker-compose.yaml"
    if [ -f "docker-compose.yml" ]; then
      compose_file="docker-compose.yml"
    elif [ -f "docker-compose.yaml" ]; then
      compose_file="docker-compose.yaml"
    else
      log_error "nginx" "cannot find docker-compose.yml or docker-compose.yaml in current directory"
      return 1
    fi
  elif [ ! -f "$compose_file" ]; then
    log_error "nginx" "compose file does not exits, [compose_file=$compose_file,service_name=$service_name] then return 1"
    return 1
  fi

  local COMPOSE_FILE_FOLDER
  COMPOSE_FILE_FOLDER=$(cd "$(dirname "$compose_file")" && pwd)
  log_info "nginx" "compose file dir is $COMPOSE_FILE_FOLDER"
  local COMPOSE_FILE_NAME
  COMPOSE_FILE_NAME=$(basename "$compose_file")

  if [ -z "$service_name" ]; then
    log_error "nginx" "service_name is empty,[compose_file=$compose_file,service_name=$service_name] then return 1"
    return 1
  fi

  local output
  if command_exists docker-compose; then
    log_info "nginx" "use docker-compose"
    log_info "nginx" "$(docker-compose -f "$compose_file" run --rm -i "$service_name" nginx -v 2>&1 | tail -n 1)"
    log_info "nginx" "docker-compose -f $compose_file run --rm -i $service_name nginx -t 2>&1 | grep 'nginx:'"
    # 2>&1 重定向到标准输出
    output=$(docker-compose -f "$compose_file" run --rm -i "$service_name" nginx -t 2>&1 | grep 'nginx:')
  elif [ "true" == "$docker_in_docker" ]; then
    log_info "nginx" "use docker compose plugin (docker in docker)"

    log_info "nginx" "$(
      docker run --rm -i -v "/var/run/docker.sock:/var/run/docker.sock" \
        -v "$COMPOSE_FILE_FOLDER:$COMPOSE_FILE_FOLDER" \
        --privileged \
        docker \
        docker compose -f "$COMPOSE_FILE_FOLDER/$COMPOSE_FILE_NAME" run --rm -i "$service_name" nginx -v 2>&1 | tail -n 1
    )"
    local compose_command="docker compose -f $COMPOSE_FILE_FOLDER/$COMPOSE_FILE_NAME run --rm -i $service_name nginx -t 2>&1 | grep 'nginx:'"
    log_info "nginx" "\n  docker run --rm -i -v /var/run/docker.sock:/var/run/docker.sock -v $COMPOSE_FILE_FOLDER:$COMPOSE_FILE_FOLDER --privileged docker $compose_command"

    output=$(
      docker run --rm -i --privileged \
        -v "/var/run/docker.sock:/var/run/docker.sock" \
        -v "$COMPOSE_FILE_FOLDER:$COMPOSE_FILE_FOLDER" \
        docker \
        docker compose -f "$COMPOSE_FILE_FOLDER/$COMPOSE_FILE_NAME" run --rm -i "$service_name" nginx -t 2>&1 | grep 'nginx:'
    )

  else
    log_info "nginx" "use docker compose plugin"
    log_info "nginx" "docker compose -f $compose_file run --rm -i $service_name nginx -t 2>&1 | grep 'nginx:'"
    output=$(docker compose -f "$compose_file" run --rm -i "$service_name" nginx -t 2>&1 | grep 'nginx:')
  fi

  if [ -z "$output" ]; then
    log_error "nginx" "output is empty. Unknown Configuration, [compose_file=$compose_file,service_name=$service_name] then return 1"
    return 1
  else
    log_info "nginx" ">>> output <<<\n\n$output\n"
    log_info "nginx" ">>> output <<<"
  fi

  # template

  #nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
  #nginx: configuration file /etc/nginx/nginx.conf test is successful

  #nginx: [emerg] unknown directive "xworker_processes" in /etc/nginx/nginx.conf:1
  #nginx: configuration file /etc/nginx/nginx.conf test failed

  #  nginx: [warn] conflicting server name "。。。" on 0.0.0.0:443, ignored
  #  nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
  #  nginx: configuration file /etc/nginx/nginx.conf test is successful

  # 获取 $output 除了最后一行的所有行
  local line_count
  local reason
  line_count=$(echo "$output" | wc -l)
  reason=$(echo "$output" | head -n $((line_count - 1)))

  # 获取 $output 的最后一行
  local status
  status=$(echo "$output" | tail -n -1)

  if echo "$status" | grep -q "successful"; then
    log_info "nginx" "$status"
    return 0
  elif echo "$status" | grep -q "failed"; then
    # skip dns validate
    if echo "$reason" | grep -q "host not found in upstream"; then
      log_warn "skip" "skip validate: host not found in upstream"
      return 0
    fi

    log_error "nginx" "$reason"
    return 1
  else
    log_error "nginx" "Unknown Configuration, [compose_file=$compose_file,service_name=$service_name] then return 1"
    return 1
  fi

}

# docker run --rm -it => docker run --rm -i
# the input device is not a TTY
# https://stackoverflow.com/questions/43099116/error-the-input-device-is-not-a-tty
