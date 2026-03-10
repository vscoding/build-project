#!/usr/bin/env bash

# compare_image_digest <from> <to> <platform>
# 示例:
#   compare_image_digest "docker.io/library/nginx:1.27" "ghcr.io/acme/nginx:1.27" "linux/amd64"
#
# 返回码:
#   0: digest 相同
#   1: digest 不同
#   2: 参数错误 / 依赖缺失
#   3: from 镜像不可用 / 不存在 / 无权限
#   4: to 镜像不可用 / 不存在 / 无权限
#   5: 指定 platform 在 from 中不存在
#   6: 指定 platform 在 to 中不存在

compare_image_digest() {
  local from="$1"
  local to="$2"
  local platform="$3"

  if [[ -z "$from" || -z "$to" || -z "$platform" ]]; then
    echo "[ERROR] 用法: compare_image_digest <from> <to> <platform>" >&2
    return 2
  fi

  if ! command -v skopeo >/dev/null 2>&1; then
    echo "[ERROR] 未找到 skopeo，请先安装 skopeo" >&2
    return 2
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "[ERROR] 未找到 jq，请先安装 jq" >&2
    return 2
  fi

  local os arch variant
  IFS='/' read -r os arch variant <<<"$platform"

  if [[ -z "$os" || -z "$arch" ]]; then
    echo "[ERROR] 非法 platform: '$platform'，期望格式如 linux/amd64 或 linux/arm64/v8" >&2
    return 2
  fi

  # 内部函数：获取某个镜像在指定平台下的 digest
  # stdout: digest
  # stderr: 错误说明
  _resolve_platform_digest() {
    local image_ref="$1"
    local os="$2"
    local arch="$3"
    local variant="$4"

    local raw rc
    if ! raw="$(skopeo inspect --raw "docker://${image_ref}" 2>&1)"; then
      rc=$?
      echo "[ERROR] 无法读取镜像: ${image_ref}" >&2

      # 尽量给出可读说明。不同 registry / skopeo 版本报错文案并不完全一致。
      if grep -qiE 'manifest unknown|name unknown|not found|reference does not exist' <<<"$raw"; then
        echo "[ERROR] 镜像不存在: ${image_ref}" >&2
      elif grep -qiE 'unauthorized|authentication required|denied|forbidden' <<<"$raw"; then
        echo "[ERROR] 无权限访问镜像: ${image_ref}" >&2
      else
        echo "[ERROR] skopeo inspect 失败: ${raw}" >&2
      fi
      return "$rc"
    fi

    # 1) 如果是 multi-arch / OCI index，按 platform 选择 descriptor.digest
    # 2) 如果是单架构 manifest，没有 manifests[]，则直接计算整份 manifest 的 sha256
    #
    # 说明：
    # - OCI / Docker schema2 的 digest 本质是该 manifest 原始 JSON 内容的 sha256
    # - 对于 index/list，需要取其中匹配 platform 的子 manifest digest
    #
    # jq 逻辑：
    # - 有 .manifests -> 说明是 index/list
    # - 无 .manifests -> 说明是单 manifest
    local digest
    digest="$(
      jq -r \
        --arg os "$os" \
        --arg arch "$arch" \
        --arg variant "$variant" '
          if has("manifests") then
            (
              .manifests[]
              | select(.platform.os == $os and .platform.architecture == $arch)
              | select(
                  if $variant == "" then
                    true
                  else
                    ((.platform.variant // "") == $variant)
                  end
                )
              | .digest
            ) // empty
          else
            empty
          end
        ' <<<"$raw"
    )"

    if [[ -n "$digest" ]]; then
      printf '%s\n' "$digest"
      return 0
    fi

    # 单架构镜像：校验平台是否匹配；匹配则对 raw manifest 求 sha256
    local single_os single_arch single_variant media_type
    single_os="$(jq -r '.os // empty' <<<"$raw")"
    single_arch="$(jq -r '.architecture // empty' <<<"$raw")"
    single_variant="$(jq -r '.variant // empty' <<<"$raw")"
    media_type="$(jq -r '.mediaType // empty' <<<"$raw")"

    # 某些 raw manifest 里可能拿不到 os/architecture（尤其特殊 artifact 或 registry 行为古怪）
    # 这种情况下，退一步用 skopeo inspect 的解析结果补充判断。
    if [[ -z "$single_os" || -z "$single_arch" ]]; then
      local parsed
      if parsed="$(skopeo inspect --override-os "$os" --override-arch "$arch" "docker://${image_ref}" 2>/dev/null)"; then
        single_os="$(jq -r '.Os // .os // empty' <<<"$parsed")"
        single_arch="$(jq -r '.Architecture // .architecture // empty' <<<"$parsed")"
        single_variant="$(jq -r '.Variant // .variant // empty' <<<"$parsed")"
      fi
    fi

    if [[ -n "$single_os" && -n "$single_arch" ]]; then
      if [[ "$single_os" != "$os" || "$single_arch" != "$arch" ]]; then
        echo "[ERROR] 镜像 ${image_ref} 不支持平台 ${os}/${arch}${variant:+/$variant}，实际为 ${single_os}/${single_arch}${single_variant:+/$single_variant}" >&2
        return 10
      fi
      if [[ -n "$variant" && -n "$single_variant" && "$single_variant" != "$variant" ]]; then
        echo "[ERROR] 镜像 ${image_ref} 不支持平台 ${os}/${arch}/${variant}，实际为 ${single_os}/${single_arch}/${single_variant}" >&2
        return 10
      fi
    fi

    # 对单 manifest 原始内容计算 sha256，得到标准 sha256:<hex> digest
    # 注意 printf '%s'，避免额外换行污染 digest。
    digest="sha256:$(printf '%s' "$raw" | sha256sum | awk '{print $1}')"
    printf '%s\n' "$digest"
    return 0
  }

  local from_digest to_digest

  if ! from_digest="$(_resolve_platform_digest "$from" "$os" "$arch" "$variant")"; then
    local rc=$?
    if [[ $rc -eq 10 ]]; then
      return 5
    fi
    return 3
  fi

  if ! to_digest="$(_resolve_platform_digest "$to" "$os" "$arch" "$variant")"; then
    local rc=$?
    if [[ $rc -eq 10 ]]; then
      return 6
    fi
    return 4
  fi

  echo "[INFO] from     = $from"
  echo "[INFO] to       = $to"
  echo "[INFO] platform = $platform"
  echo "[INFO] fromDigest = $from_digest"
  echo "[INFO] toDigest   = $to_digest"

  if [[ "$from_digest" == "$to_digest" ]]; then
    echo "[OK] digest 相同"
    return 0
  else
    echo "[DIFF] digest 不同"
    return 1
  fi
}
