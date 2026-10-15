#!/usr/bin/env bash
set -euo pipefail

# Standalone downloader for Linux Bash and Windows Git Bash; requires curl + jq.
# All relative paths are resolved from the caller's current working directory.
show_usage() {
  cat <<'EOF'
Usage:
  bash dl_raw.sh -c <config.json>
  bash <(curl -fsSL https://your-domain/github/dl_raw.sh) -c ./config.json

Options:
  -c <file>     Local JSON configuration file (required).
  -h, --help   Show this help.

Configuration:
  raws[]: repo (owner/repo), path, branch; optional saveAs and directory.
  Output directory: raws[].directory > download.directory > current directory.
  Output filename: saveAs > last component of path (no repository directories).
  Missing, null or empty optional strings use their defaults.
  request.proxy: HTTP/HTTPS/SOCKS proxy; omitted, null or empty means direct.
  Duplicate output paths in the configuration are rejected before downloading.
  Existing files are replaced only after a successful download.
  Item failures do not stop the batch; any failure produces exit status 1.
EOF
}

fail() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

config_file=''
while (($#)); do
  case $1 in
    -c)
      [[ $# -ge 2 && -n $2 && $2 != -* ]] || fail '-c requires a config file path'
      config_file=$2
      shift 2
      ;;
    -h | --help)
      show_usage
      exit 0
      ;;
    *)
      show_usage >&2
      fail "unknown argument: $1"
      ;;
  esac
done
[[ -n $config_file ]] || {
  show_usage >&2
  fail '-c is required'
}
[[ -f $config_file && -r $config_file ]] || fail "config file is not readable: $config_file"
command -v curl >/dev/null 2>&1 || fail 'curl is required'
command -v jq >/dev/null 2>&1 || fail 'jq is required'

# Parse a single snapshot and validate every item before performing any downloads.
# jq -j below avoids CRLF being appended to scalar values by native Windows jq.
config=$(jq -se '
  def plain_string:
    type == "string" and (explode | all(. >= 32 and . != 127));
  def optional_string: . == null or plain_string;
  if length != 1 then error("expected exactly one JSON object") else .[0] end
  | if type != "object" then error("configuration must be an object") else . end
  | if ((.request == null or (.request | type == "object"))
        and (.request.proxy | optional_string)
        and (.download == null or (.download | type == "object"))
        and (.download.directory | optional_string))
    then . else error("invalid request.proxy or download.directory") end
  | if (.raws | type == "array" and length > 0)
    then . else error("raws must be a non-empty array") end
  | if all(.raws[];
      type == "object"
      and (.repo | plain_string and test("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"))
      and (.branch | plain_string and length > 0)
      and (.path | plain_string and length > 0
           and (split("/") | all(. != "" and . != "." and . != "..")))
      and (.saveAs | optional_string)
      and (.directory | optional_string))
    then . else error("invalid raws item: check repo, branch, path, saveAs and directory") end
  | (.download.directory // "" | if . == "" then "." else . end) as $directory
  | {
      proxy: (.request.proxy // ""),
      files: [.raws[] | {
        url: ("https://raw.githubusercontent.com/"
              + (.repo | split("/") | map(@uri) | join("/")) + "/"
              + (.branch | @uri) + "/"
              + (.path | split("/") | map(@uri) | join("/"))),
        directory: (.directory // "" | if . == "" then $directory else . end),
        filename: (.saveAs // "" | if . == "" then null else . end)
      } + {source_name: (.path | split("/") | last)}
      | .filename = (.filename // .source_name)
      | del(.source_name)]
    }
  | if all(.files[];
      .filename != "." and .filename != ".."
      and (.filename | contains("/") or contains("\\") | not))
    then . else error("saveAs must be a filename without directory separators") end
' -- "$config_file") || fail "invalid configuration: $config_file"

proxy=$(jq -j '.proxy' <<<"$config")
curl_opts=(--disable --fail --silent --show-error --location --globoff
  --connect-timeout 15 --max-time 300 --retry 2)
if [[ -n $proxy ]]; then
  # An explicit proxy also takes precedence over NO_PROXY/no_proxy.
  curl_opts+=(--proxy "$proxy" --noproxy '')
  printf '[INFO] Download mode: configured proxy\n'
else
  # Empty --proxy disables HTTP_PROXY/HTTPS_PROXY/ALL_PROXY environment settings.
  curl_opts+=(--proxy '')
  printf '[INFO] Download mode: direct\n'
fi

urls=()
targets=()
total=0
success=0
failed=0

# Resolve directory aliases before comparing targets, e.g. out and ./out.
while IFS= read -r item; do
  total=$((total + 1))
  url=$(jq -j '.url' <<<"$item")
  directory=$(jq -j '.directory' <<<"$item")
  filename=$(jq -j '.filename' <<<"$item")
  if ! mkdir -p -- "$directory"; then
    printf '[ERROR] Cannot create directory: %s\n' "$directory" >&2
    failed=$((failed + 1))
    continue
  fi
  if ! directory=$(cd -- "$directory" && pwd -P); then
    printf '[ERROR] Cannot resolve output directory\n' >&2
    failed=$((failed + 1))
    continue
  fi
  target="${directory%/}/$filename"
  for previous in "${targets[@]}"; do
    [[ $target != "$previous" ]] || fail "duplicate output path: $target"
  done
  if [[ -d $target ]]; then
    printf '[ERROR] Output path is a directory: %s\n' "$target" >&2
    failed=$((failed + 1))
    continue
  fi
  urls+=("$url")
  targets+=("$target")
done < <(jq -c '.files[]' <<<"$config")

temp_file=''
cleanup() {
  if [[ -n $temp_file ]]; then
    rm -f -- "$temp_file"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for ((i = 0; i < ${#urls[@]}; i++)); do
  url=${urls[i]}
  target=${targets[i]}
  printf '[INFO] Downloading %s -> %s\n' "$url" "$target"
  if ! temp_file=$(mktemp "${target}.tmp.XXXXXX"); then
    printf '[ERROR] Cannot create temporary file for: %s\n' "$target" >&2
    failed=$((failed + 1))
    continue
  fi
  # -T prevents a destination directory from accidentally accepting the temp file.
  if curl "${curl_opts[@]}" --output "$temp_file" -- "$url" &&
    mv -fT -- "$temp_file" "$target"; then
    temp_file=''
    success=$((success + 1))
    printf '[INFO] Saved: %s\n' "$target"
  else
    printf '[ERROR] Download failed: %s\n' "$url" >&2
    cleanup
    temp_file=''
    failed=$((failed + 1))
  fi
done

printf '[INFO] Completed: total=%d success=%d failed=%d\n' "$total" "$success" "$failed"
[[ $failed -eq 0 ]]
