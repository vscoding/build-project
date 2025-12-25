#!/bin/bash
# shell library, must be sourced

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

  local msg="GitHub Actions Trigger: ${joined_keywords} ($(date +'%Y-%m-%d %H:%M:%S'))"

  echo "✅ Using keywords: $joined_keywords"
  echo "🔄 Switching to branch: $branch"

  git checkout "$branch"
  git commit --allow-empty -m "$msg"
  git push origin "$branch"

  echo "🚀 Trigger pushed successfully!"
}
