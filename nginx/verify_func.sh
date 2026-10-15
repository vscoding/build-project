#!/usr/bin/env bash
# shellcheck disable=SC1090 disable=SC2028
[ -z "${ROOT_URI:-}" ] && source <(curl -fsSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

source <(curl -fsSL "$ROOT_URI/func/log.sh")
source <(curl -fsSL "$ROOT_URI/func/command_exists.sh")

function verify_nginx_configuration() {
  log_info "nginx" "Verify the nginx configuration used by Docker Compose"

  local service_name="${1:-}"
  local compose_file="${2:-}"

  if [ -z "$service_name" ]; then
    log_error "nginx" "service_name is empty, [compose_file=$compose_file,service_name=$service_name]"
    return 1
  fi

  if [ -z "$compose_file" ]; then
    log_info "nginx" "compose file is empty, try the default Compose file names"
    local candidate
    for candidate in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
      if [ -f "$candidate" ]; then
        compose_file="$candidate"
        break
      fi
    done

    if [ -z "$compose_file" ]; then
      log_error "nginx" "cannot find a Compose file in the current directory"
      return 1
    fi
  elif [ ! -f "$compose_file" ]; then
    log_error "nginx" "compose file does not exist, [compose_file=$compose_file,service_name=$service_name]"
    return 1
  fi

  local compose_file_folder
  if compose_file_folder=$(cd -- "$(dirname -- "$compose_file")" && pwd -P); then
    log_info "nginx" "compose file dir is $compose_file_folder"
  else
    log_error "nginx" "cannot resolve compose file directory: $compose_file"
    return 1
  fi

  local compose_file_name
  compose_file_name=$(basename -- "$compose_file")

  local -a compose_command
  if command_exists docker && docker compose version >/dev/null 2>&1; then
    log_info "nginx" "use docker compose plugin"
    compose_command=(docker compose)
  elif command_exists docker-compose && docker-compose version >/dev/null 2>&1; then
    log_info "nginx" "use docker-compose"
    compose_command=(docker-compose)
  elif command_exists docker; then
    case "${OSTYPE:-}" in
      msys* | cygwin*)
        log_error "nginx" "Docker Compose is unavailable in Windows Git Bash; enable the Docker Desktop Compose plugin"
        return 1
        ;;
    esac

    log_warn "nginx" "Compose plugin is unavailable, use the Docker CLI image"
    compose_file="$compose_file_folder/$compose_file_name"
    compose_command=(
      docker run --rm
      -v "/var/run/docker.sock:/var/run/docker.sock"
      -v "$compose_file_folder:$compose_file_folder"
      -w "$compose_file_folder"
      docker
      docker compose
    )
  else
    log_error "nginx" "neither docker nor docker-compose is available"
    return 1
  fi

  local output
  local exit_code
  if output=$("${compose_command[@]}" -f "$compose_file" config -q 2>&1); then
    log_info "nginx" "Docker Compose configuration is valid"
  else
    exit_code=$?
    log_error "nginx" "Docker Compose configuration is invalid (exit_code=$exit_code)\n$output"
    return "$exit_code"
  fi

  log_info "nginx" "run nginx configuration validation"
  if output=$("${compose_command[@]}" -f "$compose_file" run --rm -T "$service_name" nginx -t 2>&1); then
    log_info "nginx" ">>> output <<<\n\n$output\n"
    return 0
  else
    exit_code=$?
  fi

  if grep -Fq "host not found in upstream" <<<"$output"; then
    log_warn "skip" "skip validate: host not found in upstream\n$output"
    return 0
  fi

  if [ -z "$output" ]; then
    output="nginx validation failed without output"
  fi
  log_error "nginx" "nginx configuration validation failed (exit_code=$exit_code)\n$output"
  return "$exit_code"
}
