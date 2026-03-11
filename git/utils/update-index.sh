#!/bin/bash
# shellcheck disable=SC2164,SC1090,SC2086
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
echo -e "\033[0;32mROOT_URI=$ROOT_URI\033[0m"
# export ROOT_URI=https://dev.kubectl.net
source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/ostype.sh)

if is_windows; then
  log_info "build" "build in windows"
  export MSYS_NO_PATHCONV=1
fi

set -euo pipefail

log_info "chmod" "start make executable scan"

curr_dir=$(pwd)
log_info "chmod" "current directory: $curr_dir"
read -r -n 1 -p "This script will scan all tracked files in git and make .sh files and shebang scripts executable. Do you want to continue? (y/n) " REPLY
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  log_info "chmod" "aborted by user"
  exit 0
fi

# 1) Traditional .sh files (tracked by git)
sh_changed=0
while IFS= read -r f; do
  git update-index --chmod=+x -- "$f"
  sh_changed=$((sh_changed + 1))
  log_info "chmod" "git update-index --chmod=+x $f (.sh)"
done < <(git ls-files '*.sh')

# 2) Suffix-less scripts with shebang (for example install_packages/run-script)
# Only apply to tracked non-.sh files.
shebang_changed=0
while IFS= read -r -d '' f; do
  [[ "$f" == *.sh ]] && continue
  if head -c 2 "$f" | grep -q '^#!'; then
    git update-index --chmod=+x -- "$f"
    shebang_changed=$((shebang_changed + 1))
    log_info "chmod" "git update-index --chmod=+x $f (shebang)"
  fi
done < <(git ls-files -z)

log_info "chmod" "done, .sh changed: $sh_changed, shebang changed: $shebang_changed"
