#!/bin/bash
# shellcheck disable=SC1090

function usage() {
  cat <<EOF
Usage:
  update_readme.sh [options]
  update_dockerhub_readme [options]

Options:
  -u, --user <user>             Docker Hub username. Env: DOCKER_USER
  -p, --password <password>     Docker Hub password or personal access token. Env: DOCKER_PASSWORD
  -r, --repo <repo>             Docker Hub repository name. Env: REPO_NAME
  -f, --file <path>             README file path. Env: README_PATH. Default: ./README.md
  -d, --description <text>      Docker Hub short description. Env: SHORT_DESC
  -x, --proxy <url>             HTTP proxy for curl. Env: HTTP_PROXY
      --root-uri <url>          Root URI for helper scripts. Env: ROOT_URI
  -h, --help                    Show this help message

Environment variables are used as defaults. Command-line options override them.
EOF
}

function update_readme_require_value() {
  local name="$1"
  local value="$2"

  if [[ -z "$value" ]]; then
    log_error "config" "$name is required"
    return 1
  fi
}

function update_dockerhub_readme() {
  local docker_user="${DOCKER_USER:-}"
  local docker_password="${DOCKER_PASSWORD:-}"
  local repo_name="${REPO_NAME:-}"
  local readme_path="${README_PATH:-./README.md}"
  local short_desc="${SHORT_DESC:-这是一个通过脚本自动更新的镜像描述。}"
  local http_proxy="${HTTP_PROXY:-}"
  local root_uri="${ROOT_URI:-}"
  local token_response=""
  local token=""
  local login_payload=""
  local api_payload=""
  local response_code=""
  local -a curl_proxy_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -u | --user)
        if [[ $# -lt 2 ]]; then
          printf 'Option %s requires an argument\n' "$1" >&2
          usage
          return 1
        fi
        docker_user="$2"
        shift 2
        ;;
      --user=*)
        docker_user="${1#*=}"
        shift
        ;;
      -p | --password)
        if [[ $# -lt 2 ]]; then
          printf 'Option %s requires an argument\n' "$1" >&2
          usage
          return 1
        fi
        docker_password="$2"
        shift 2
        ;;
      --password=*)
        docker_password="${1#*=}"
        shift
        ;;
      -r | --repo)
        if [[ $# -lt 2 ]]; then
          printf 'Option %s requires an argument\n' "$1" >&2
          usage
          return 1
        fi
        repo_name="$2"
        shift 2
        ;;
      --repo=*)
        repo_name="${1#*=}"
        shift
        ;;
      -f | --file)
        if [[ $# -lt 2 ]]; then
          printf 'Option %s requires an argument\n' "$1" >&2
          usage
          return 1
        fi
        readme_path="$2"
        shift 2
        ;;
      --file=*)
        readme_path="${1#*=}"
        shift
        ;;
      -d | --description)
        if [[ $# -lt 2 ]]; then
          printf 'Option %s requires an argument\n' "$1" >&2
          usage
          return 1
        fi
        short_desc="$2"
        shift 2
        ;;
      --description=*)
        short_desc="${1#*=}"
        shift
        ;;
      -x | --proxy)
        if [[ $# -lt 2 ]]; then
          printf 'Option %s requires an argument\n' "$1" >&2
          usage
          return 1
        fi
        http_proxy="$2"
        shift 2
        ;;
      --proxy=*)
        http_proxy="${1#*=}"
        shift
        ;;
      --root-uri)
        if [[ $# -lt 2 ]]; then
          printf 'Option %s requires an argument\n' "$1" >&2
          usage
          return 1
        fi
        root_uri="$2"
        shift 2
        ;;
      --root-uri=*)
        root_uri="${1#*=}"
        shift
        ;;
      -h | --help)
        usage
        return 0
        ;;
      *)
        printf 'Invalid option: %s\n' "$1" >&2
        usage
        return 1
        ;;
    esac
  done

  if [[ -n "$http_proxy" ]]; then
    curl_proxy_args=(-x "$http_proxy")
  fi

  if [[ -z "$root_uri" ]]; then
    source <(curl -sSL https://dev.kubectl.org/init)
    root_uri="${ROOT_URI:-}"
  fi

  if [[ -z "$root_uri" ]]; then
    printf 'ROOT_URI is required\n' >&2
    return 1
  fi

  source <(curl -sSL "$root_uri/func/log.sh")
  source <(curl -sSL "$root_uri/func/ostype.sh")

  log_info "config" "ROOT_URI=$root_uri"
  if [[ ${#curl_proxy_args[@]} -gt 0 ]]; then
    log_info "proxy" "HTTP_PROXY is set, Docker Hub requests will use proxy"
  else
    log_info "proxy" "HTTP_PROXY is not set, Docker Hub requests will connect directly"
  fi

  if is_windows; then
    log_info "build" "build in windows"
    export MSYS_NO_PATHCONV=1
  fi

  update_readme_require_value "DOCKER_USER" "$docker_user" || return 1
  update_readme_require_value "DOCKER_PASSWORD" "$docker_password" || return 1
  update_readme_require_value "REPO_NAME" "$repo_name" || return 1

  if ! command -v jq >/dev/null 2>&1; then
    log_error "dependency" "jq is required"
    return 1
  fi

  if [[ ! -f "$readme_path" ]]; then
    log_error "readme" "file not found: $readme_path"
    return 1
  fi

  log_info "dockerhub" "start update Docker Hub README for ${docker_user}/${repo_name}"

  log_info "auth" "request Docker Hub token"
  login_payload=$(jq -n \
    --arg identifier "$docker_user" \
    --arg secret "$docker_password" \
    '{identifier: $identifier, secret: $secret}')

  if ! token_response=$(curl "${curl_proxy_args[@]}" -sSL \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$login_payload" \
    "https://hub.docker.com/v2/auth/token"); then
    log_error "auth" "failed to request Docker Hub token"
    return 1
  fi

  token=$(printf "%s" "$token_response" | jq -r '.access_token // .token // empty')

  if [[ "$token" == "null" || -z "$token" ]]; then
    log_error "auth" "login failed, please check DOCKER_USER and DOCKER_PASSWORD"
    return 1
  fi

  log_info "readme" "read and convert $readme_path"
  api_payload=$(jq -n \
    --arg desc "$short_desc" \
    --rawfile full_desc "$readme_path" \
    '{description: $desc, full_description: $full_desc}')

  log_info "dockerhub" "upload README to Docker Hub"
  if ! response_code=$(curl "${curl_proxy_args[@]}" -sS -o /dev/null -w "%{http_code}" \
    -X PATCH \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "$api_payload" \
    "https://hub.docker.com/v2/repositories/${docker_user}/${repo_name}/"); then
    log_error "dockerhub" "failed to request Docker Hub repository update API"
    return 1
  fi

  if [[ "$response_code" == "200" ]]; then
    log_info "dockerhub" "Docker Hub README updated successfully"
  else
    log_error "dockerhub" "API returned HTTP $response_code, please check REPO_NAME and permissions"
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  update_dockerhub_readme "$@"
  exit $?
fi
