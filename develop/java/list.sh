#!/bin/bash
# shellcheck disable=SC1090,SC2086,SC2155,SC2128,SC2028
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/command_exists.sh)

if ! command_exists jps; then
  log_error "prepare" "command jps does not exist"
  exit
fi

if ! command_exists jstat; then
  log_error "prepare" "command jstat does not exist"
  exit
fi

# Get the list of Java processes with their names
processes=$(jps -v)

# Iterate over each process and get memory usage
while read -r line; do
  pid=$(echo $line | awk '{print $1}')
  name=$(echo $line | awk '{print $2}')

  # Skip the jps process
  if [ "$name" == "Jps" ]; then
    continue
  fi

  # Get the memory usage using jstat
  memory_usage_kb=$(jstat -gc $pid | awk 'NR==2 {print $3+$4+$6+$8+$9+$10}')
  memory_usage_mb=$(echo "scale=2; $memory_usage_kb / 1024" | bc)
  log_info "java" "Process ID: $pid, Name: $name, Memory Usage: ${memory_usage_mb}MB"
done <<<"$processes"
