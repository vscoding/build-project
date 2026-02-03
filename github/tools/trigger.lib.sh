#!/bin/bash
# shellcheck disable=SC2155
# shell library, must be sourced

select_keywords() {
  local -n out=$1
  local selections
  local args=()
  local pick_list=()

  echo "Available keywords:"
  for i in "${!key_word_list[@]}"; do
    idx=$((i + 1))
    printf "%2d) %s\n" "$idx" "${key_word_list[$i]}"
  done
  printf "Enter selection(s), space-separated (e.g., 1 2): "
  read -r selections
  if [[ -z "$selections" ]]; then
    echo "No selection provided."
    exit 1
  fi

  IFS=' ' read -r -a pick_list <<<"$selections"
  for sel in "${pick_list[@]}"; do
    sel="${sel//[[:space:]]/}"
    if [[ ! "$sel" =~ ^[0-9]+$ ]]; then
      echo "Invalid selection: $sel"
      exit 1
    fi
    if ((sel < 1 || sel > ${#key_word_list[@]})); then
      echo "Selection out of range: $sel"
      exit 1
    fi
    args+=("${key_word_list[$((sel - 1))]}")
  done

  out=("${args[@]}")
}

trigger_git_commit() {
  local valid_array_name="$1"
  shift

  local branch="${1:-main}"
  shift || true

  declare -n VALID_KEYS="$valid_array_name"
  local INPUT_KEYS=("$@")

  # ---------- 校验 ----------
  if [[ ${#INPUT_KEYS[@]} -eq 0 ]]; then
    echo "⚠️  No keyword provided."
    echo "👉 Valid keywords are: ${VALID_KEYS[*]}"
    return 0
  fi

  local invalid_keys=()

  for key in "${INPUT_KEYS[@]}"; do
    local found=false
    for valid in "${VALID_KEYS[@]}"; do
      if [[ "$key" == "$valid" ]]; then
        found=true
        break
      fi
    done
    [[ $found == false ]] && invalid_keys+=("$key")
  done

  if [[ ${#invalid_keys[@]} -gt 0 ]]; then
    echo "❌ Invalid keyword(s): ${invalid_keys[*]}"
    echo "👉 Valid keywords are: ${VALID_KEYS[*]}"
    return 1
  fi

  # ---------- commit ----------
  local joined_keywords
  joined_keywords=$(
    IFS=' '
    echo "${INPUT_KEYS[*]}"
  )

  local commit_msg="GitHub Actions Trigger: ${joined_keywords} ($(date +'%Y-%m-%d %H:%M:%S'))"

  echo "✅ Using keywords: $joined_keywords"
  echo "🔄 Switching to branch: $branch"

  git checkout "$branch"
  git commit --allow-empty -m "$commit_msg"
  git push origin "$branch"

  echo "🚀 Trigger pushed successfully!"
}
