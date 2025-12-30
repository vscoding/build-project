#!/bin/bash
# shellcheck disable=SC2164,SC1090,SC2086,SC2155
export ROOT_URI="https://dev.kubectl.org"
echo -e "\033[0;32mROOT_URI=$ROOT_URI\033[0m"

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/ostype.sh)
source <(curl -sSL $ROOT_URI/func/command_exists.sh)

if is_windows; then
  log_info "build" "build in windows"
  export MSYS_NO_PATHCONV=1
fi

function nginx_action() {
  function statistic() {
    # Define the file suffixes to be counted
    local suffixes=("conf" "lua")

    for suffix in "${suffixes[@]}"; do
      local file_count=$(find . -name "*.${suffix}" | wc -l)
      log_info "statistic" "Total .${suffix} files: $file_count"

      local total_lines=0
      while IFS= read -r file; do
        local line_count=$(wc -l <"$file")
        total_lines=$((total_lines + line_count))
      done < <(find . -name "*.${suffix}")
      log_info "statistic" "Total .${suffix} lines: $total_lines"
    done
  }

  function git_pull() {
    if [ -d ".git" ]; then
      log_info "git" "pull latest code"
      git pull origin HEAD
    fi
  }

  function update_resources() {
    local resources=("$@")
    for resource in "${resources[@]}"; do
      echo "updating resource: $resource"
      if [ -f ".migrate/update_tpl.sh" ]; then
        bash .migrate/update_tpl.sh -i "$resource"
      else
        log_error "update" "update script .migrate/update_tpl.sh not found"
      fi
    done
  }

  function docker_compose_pull() {
    if command_exists docker-compose; then
      log_info "docker" "docker-compose pull"
      docker-compose pull
    else
      log_info "docker" "docker compose pull"
      docker compose pull
    fi
  }

  # Docker compose down
  function docker_compose_down() {
    if command_exists docker-compose; then
      log_info "docker" "docker-compose down"
      docker-compose down
    else
      log_info "docker" "docker compose down"
      docker compose down
    fi
  }

  # Docker compose up
  function docker_compose_up() {
    if command_exists docker-compose; then
      log_info "docker" "docker-compose up -d"
      docker-compose up -d
    else
      log_info "docker" "docker compose up -d"
      docker compose up -d
    fi
  }

  function stop() {
    docker_compose_down || true
    docker_compose_pull || true
    git_pull
  }

  function start() {
    local resources=("$@")
    update_resources "${resources[@]}"
    docker_compose_pull || true
    docker_compose_up
  }

  local action="$1"
  local start_resources_key="$2"
  local start_all_resources_key="$3"
  log_info "action" "start action: $action"

  declare -n start_resources="$start_resources_key"
  declare -n start_all_resources="$start_all_resources_key"

  case $action in
    "statistic")
      statistic
      ;;
    "update")
      git_pull
      docker_compose_pull
      update_resources "${start_all_resources[@]}"
      ;;
    "stop")
      stop
      ;;
    "start")
      start "${start_resources[@]}"
      ;;
    "start_all")
      start "${start_all_resources[@]}"
      ;;
    "restart")
      stop
      start "${start_resources[@]}"
      ;;
    "restart_all")
      stop
      start "${start_all_resources[@]}"
      ;;
    *)
      log_error "action" "unknown action: $action"
      exit 0
      ;;
  esac

}
