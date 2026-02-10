#!/bin/bash
# shellcheck disable=SC2164,SC1090,SC2086,SC2162
[ -z "$ROOT_URI" ] && source <(curl -sSL https://dev.kubectl.org/init)
printf "\033[0;32mROOT_URI=%s\033[0m\n" "$ROOT_URI"
# export ROOT_URI=https://dev.kubectl.net
source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/ostype.sh)

if is_windows; then
  log_info "build" "build in windows"
  export MSYS_NO_PATHCONV=1
fi

#ls 'D:\jetbrains\idea.cache\system\github-actions\cache'

GITHUB_ACTIONS_CACHE_DIR=${GITHUB_ACTIONS_CACHE_DIR:-}
if [ -z "$GITHUB_ACTIONS_CACHE_DIR" ]; then
  log_error "env" "GITHUB_ACTIONS_CACHE_DIR is not set"
  exit 1
fi

# read action from input ,e.g. owner/repo@ref
read -r -p "Enter the GitHub action (e.g. owner/repo@ref): " action_input

# validate
if [[ ! "$action_input" =~ ^[^/]+/[^/@]+@.+$ ]]; then
  log_error "input" "Invalid format. Expected owner/repo@ref"
  exit 1
fi

# clear old directory. GITHUB_ACTIONS_CACHE_DIR + owner/repo@ref -> owner/repo/ref
action_dir="$GITHUB_ACTIONS_CACHE_DIR/${action_input//@//}"
if [ -d "$action_dir" ]; then
  log_info "cache" "Clearing old cache at $action_dir"
  rm -rf "$action_dir"
else
  log_info "cache" "No existing cache found at $action_dir"
fi

mkdir -p "$action_dir"

# e.g. https://raw.githubusercontent.com/{owner}/{repo}/refs/tags/{tag}action.yml
owner_repo=${action_input%@*}
ref=${action_input#*@}
action_url="https://raw.githubusercontent.com/$owner_repo/refs/tags/$ref/action.yml"

log_info "download" "Downloading action.yml from $action_url"

HTTP_PROXY=${HTTP_PROXY:-} HTTPS_PROXY=${HTTPS_PROXY:-} curl -sSL -o "$action_dir/action.yml" "$action_url"

log_info "success" "Action refreshed successfully at $action_dir/action.yml"
