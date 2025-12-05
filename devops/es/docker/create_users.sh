#!/bin/bash
# shellcheck disable=SC1090,SC2086,SC2155,SC2128,SC2028,SC2164,SC2162
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/command_exists.sh)

container_name=$1
es_password=$2

if [ -z $container_name ]; then
  container_name="elasticsearch"
  log_info "elasticsearch" "default container_name=$container_name"
fi

if [ -z $es_password ]; then
  es_password="elastic"
  log_info "elasticsearch" "default es_password=$es_password"
fi

if ! command_exists docker; then
  log_error "elasticsearch" "docker is not installed"
  exit 1
fi

if [ "$(docker ps -a --filter "name=$container_name" --format "{{.Names}}")" == "$container_name" ]; then
  log_info "elasticsearch" "Container $container_name exists."
else
  log_error "elasticsearch" "Container $container_name does not exist."
  exit 1
fi

# Set passwords for built-in users
# ERROR: Invalid username [elastic]... Username [elastic] is reserved and may not be used., with exit code 65
# ERROR: Invalid username [kibana]... Username [kibana] is reserved and may not be used., with exit code 65
# ERROR: Invalid username [apm_system]... Username [apm_system] is reserved and may not be used., with exit code 65

usernames=("admin" "kibana_sys" "logstash" "beats" "apm_sys")

for username in "${usernames[@]}"; do
  log_warn "elasticsearch" "delete user $username"
  docker exec -it $container_name \
    bin/elasticsearch-users userdel $username
done

roles=("superuser" "kibana_system" "logstash_system" "beats_system" "apm_system")
for index in "${!roles[@]}"; do
  log_info "elasticsearch" "add user|index: $index, username: ${usernames[$index]}, role: ${roles[$index]}"
  docker exec -it --user 1000:1000 $container_name \
    bin/elasticsearch-users useradd ${usernames[$index]} -p $es_password -r ${roles[$index]}
done

log_info "elasticsearch" "list users"
docker exec -it $container_name bin/elasticsearch-users list
