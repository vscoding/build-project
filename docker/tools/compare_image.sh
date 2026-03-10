#!/usr/bin/env bash

# compare_image_layers <from> <to> <platform>
#
# 示例:
#   compare_image_layers \
#     "docker.m.kubectl.net/nginx:1.27" \
#     "registry.cn-shanghai.aliyuncs.com/iproute/nginx:1.27" \
#     "linux/amd64"
#
# 语义:
#   基于 skopeo --override-os/--override-arch inspect 的结果，
#   只比较指定平台下的 Layers 列表（顺序敏感）。
#   Layers 完全一致，则认为镜像相同。
#
# 返回码:
#   0: layers 相同
#   1: layers 不同
#   2: 参数错误 / 依赖缺失
#   3: from 镜像不可用 / 不存在 / 无权限
#   4: to 镜像不可用 / 不存在 / 无权限
#   5: 指定 platform 在 from 中不存在 / 不匹配
#   6: 指定 platform 在 to 中不存在 / 不匹配

compare_image_layers() {
  local from="${1:-}"
  local to="${2:-}"
  local platform="${3:-}"

  if [[ -z "$from" || -z "$to" || -z "$platform" ]]; then
    echo "[ERROR] 用法: compare_image_layers <from> <to> <platform>" >&2
    return 2
  fi

  local dep
  for dep in skopeo jq; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "[ERROR] 未找到依赖: $dep" >&2
      return 2
    fi
  done

  local os arch variant
  IFS='/' read -r os arch variant <<<"$platform"

  if [[ -z "$os" || -z "$arch" ]]; then
    echo "[ERROR] 非法 platform: '$platform'，期望格式如 linux/amd64 或 linux/arm64/v8" >&2
    return 2
  fi

  local from_layers to_layers rc

  from_layers="$(_resolve_layers_by_inspect "$from" "$os" "$arch" "$variant")"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    case "$rc" in
      10) return 5 ;;
      *) return 3 ;;
    esac
  fi

  to_layers="$(_resolve_layers_by_inspect "$to" "$os" "$arch" "$variant")"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    case "$rc" in
      10) return 6 ;;
      *) return 4 ;;
    esac
  fi

  echo "[INFO] from     = $from"
  echo "[INFO] to       = $to"
  echo "[INFO] platform = $platform"
  echo "[INFO] fromLayers:"
  printf '%s\n' "$from_layers"
  echo "[INFO] toLayers:"
  printf '%s\n' "$to_layers"

  if [[ "$from_layers" == "$to_layers" ]]; then
    echo "[OK] layers 相同"
    return 0
  else
    echo "[DIFF] layers 不同"
    return 1
  fi
}

# ---------- 内部函数 ----------

_normalize_docker_ref() {
  local image_ref="$1"
  if [[ "$image_ref" == docker://* ]]; then
    printf '%s\n' "$image_ref"
  else
    printf 'docker://%s\n' "$image_ref"
  fi
}

_classify_skopeo_error() {
  local image_ref="$1"
  local err_text="$2"

  echo "[ERROR] 无法读取镜像: ${image_ref}" >&2

  if grep -qiE 'manifest unknown|name unknown|not found|reference does not exist|requested access to the resource is denied because it does not exist' <<<"$err_text"; then
    echo "[ERROR] 镜像不存在: ${image_ref}" >&2
  elif grep -qiE 'unauthorized|authentication required|denied|forbidden|access denied' <<<"$err_text"; then
    echo "[ERROR] 无权限访问镜像: ${image_ref}" >&2
  else
    echo "[ERROR] skopeo inspect 失败: ${err_text}" >&2
  fi
}

# 基于 skopeo inspect 获取指定平台的解析结果
# stdout: inspect 返回的 JSON
# return:
#   0 成功
#   非 0 失败
_fetch_inspect_json() {
  local image_ref="$1"
  local os="$2"
  local arch="$3"
  local variant="$4"

  local docker_ref
  docker_ref="$(_normalize_docker_ref "$image_ref")"

  local cmd=(
    skopeo
    --override-os "$os"
    --override-arch "$arch"
  )

  if [[ -n "$variant" ]]; then
    cmd+=(--override-variant "$variant")
  fi

  cmd+=(inspect "$docker_ref")

  local out
  out="$("${cmd[@]}" 2>&1)"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    _classify_skopeo_error "$image_ref" "$out"
    return "$rc"
  fi

  printf '%s\n' "$out"
}

# 解析指定平台下的 layers
#
# stdout:
#   每行一个 layer digest
#
# return:
#   0  成功
#   10 平台不匹配 / inspect 结果异常
#   其他 非 0 读取失败
_resolve_layers_by_inspect() {
  local image_ref="$1"
  local os="$2"
  local arch="$3"
  local variant="$4"

  local json
  json="$(_fetch_inspect_json "$image_ref" "$os" "$arch" "$variant")"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    return "$rc"
  fi

  local actual_os actual_arch actual_variant
  actual_os="$(jq -r '.Os // .os // empty' <<<"$json")"
  actual_arch="$(jq -r '.Architecture // .architecture // empty' <<<"$json")"
  actual_variant="$(jq -r '.Variant // .variant // empty' <<<"$json")"

  if [[ -n "$actual_os" && -n "$actual_arch" ]]; then
    if [[ "$actual_os" != "$os" || "$actual_arch" != "$arch" ]]; then
      echo "[ERROR] 镜像 ${image_ref} 不支持平台 ${os}/${arch}${variant:+/$variant}，实际为 ${actual_os}/${actual_arch}${actual_variant:+/$actual_variant}" >&2
      return 10
    fi

    if [[ -n "$variant" && -n "$actual_variant" && "$actual_variant" != "$variant" ]]; then
      echo "[ERROR] 镜像 ${image_ref} 不支持平台 ${os}/${arch}/${variant}，实际为 ${actual_os}/${actual_arch}/${actual_variant}" >&2
      return 10
    fi
  fi

  local layers
  layers="$(jq -er '.Layers[]' <<<"$json" 2>/dev/null)"
  rc=$?
  if [[ $rc -ne 0 || -z "$layers" ]]; then
    echo "[ERROR] 镜像 ${image_ref} 未返回有效的 Layers 字段" >&2
    return 10
  fi

  printf '%s\n' "$layers"
}
