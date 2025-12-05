#!/bin/bash
# shellcheck disable=SC2086 disable=SC1090 disable=SC2181
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)
source <(curl -sSL "$ROOT_URI/func/log.sh")

# 归一化仓库 URL
function normalize_repo_url() {
  local url=$1

  # 去掉结尾 .git 和 /
  url=${url%.git}
  url=${url%/}

  # ssh => https 格式统一
  url=$(echo "$url" | sed -E 's#^git@([^:]+):#https://\1/#')

  # 去掉 https://user@host -> https://host
  url=$(echo "$url" | sed -E 's#^(https?://)[^@]+@#\1#')

  echo "$url"
}

# 判断是否相同仓库
function is_same_repo() {
  local repo_url=$1
  local curr_origin=$2

  [[ -z "$curr_origin" ]] && {
    curr_origin=$(git remote get-url origin 2>/dev/null || echo "")
  }

  if [[ -z "$curr_origin" ]]; then
    log_error "origin" "cannot get current origin"
    return 2
  fi

  local n1 n2
  n1=$(normalize_repo_url "$repo_url")
  n2=$(normalize_repo_url "$curr_origin")

  [[ "$n1" == "$n2" ]]
}

# 获取当前分支（若未传入）
function get_branch() {
  local branch=$1
  if [[ -z "$branch" ]]; then
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  fi
  [[ -z "$branch" ]] && {
    log_error "branch" "cannot determine branch"
    return 1
  }
  echo "$branch"
}

# 通用 mirror 函数
function mirror_repo() {
  local repo_url=$1
  local branch=$2
  local mode=$3 # "mirror" 或 "branch"

  is_same_repo "$repo_url" && {
    log_warn "mirror" "same repo, skip: $repo_url"
    return 0
  }

  branch=$(get_branch "$branch") || return 1

  case "$mode" in
    mirror)
      log_info "mirror" "pushing --mirror to $repo_url"
      git push --mirror "$repo_url"
      ;;
    branch)
      log_info "mirror" "pushing branch '$branch' to $repo_url"
      git push "$repo_url" "$branch"
      ;;
    *)
      log_error "mirror" "unknown mode: $mode"
      return 1
      ;;
  esac
}

# code.kubectl.net: 完整镜像
function mirror_to_code() {
  local repo=$1 branch=$2
  mirror_repo "https://code.kubectl.net/$repo" "$branch" mirror
}

# github: 完整镜像
function mirror_to_github() {
  local repo=$1 branch=$2
  mirror_repo "git@github.com:$repo" "$branch" mirror
}

# gitlab: 仅按分支推
function mirror_to_gitlab() {
  local repo=$1 branch=$2
  mirror_repo "git@gitlab.com:$repo" "$branch" branch
}

# 批量镜像
function batch_mirror() {
  local repo=$1 branch=$2
  [[ -z "$repo" ]] && {
    log_error "batch_mirror" "repository not specified"
    return 1
  }
  mirror_to_code "$repo" "$branch"
  mirror_to_gitlab "$repo" "$branch"
  mirror_to_github "$repo" "$branch"
}
