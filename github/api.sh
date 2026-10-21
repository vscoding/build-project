#!/usr/bin/env bash
# Usage: fetch_latest_tag owner/repo [--match REGEX] [--exclude REGEX] [--proxy URL]
#                         [--token TOKEN] [--max-pages N]
# Returns the first matching tag in API order, without version sorting.
# --exclude skips matching tag names, including those accepted by --match.
# An omitted or empty --exclude excludes nothing.
# Defaults: match all tags, environment proxy, GITHUB_TOKEN, one page (100 tags).
# --proxy '' disables proxying; --token '' disables authentication.
# --max-pages accepts integers from 1 to 2147483647.
# stdout: tag plus newline on success; otherwise empty. Diagnostics go to stderr.
# Status: 0 = found, 1 = no match in queried pages, 2 = invalid arguments/regex,
#         3 = request, dependency, or response error.
function fetch_latest_tag() {
  local repo=${1:-}
  if [[ ! $repo =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    printf 'fetch_latest_tag: expected repository owner/repo\n' >&2
    return 2
  fi
  shift

  local match_pattern='' proxy='' proxy_set=0 github_token=${GITHUB_TOKEN:-} max_pages=1
  local exclude_pattern=''
  while (($# > 0)); do
    case $1 in
      --match | --exclude | --proxy | --token | --max-pages)
        if (($# < 2)) || [[ $2 == --* ]]; then
          printf 'fetch_latest_tag: %s requires a value\n' "$1" >&2
          return 2
        fi
        case $1 in
          --match) match_pattern=$2 ;;
          --exclude) exclude_pattern=$2 ;;
          --proxy)
            proxy=$2
            proxy_set=1
            ;;
          --token) github_token=$2 ;;
          --max-pages) max_pages=$2 ;;
        esac
        shift 2
        ;;
      *)
        printf 'fetch_latest_tag: unknown argument: %s\n' "$1" >&2
        return 2
        ;;
    esac
  done
  if [[ ! $max_pages =~ ^[1-9][0-9]*$ ]] || ((${#max_pages} > 10)) ||
    ((max_pages > 2147483647)); then
    printf 'fetch_latest_tag: --max-pages must be an integer from 1 to 2147483647\n' >&2
    return 2
  fi
  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    printf 'fetch_latest_tag: curl and jq are required\n' >&2
    return 3
  fi
  # Compile even when the response is empty, before making any requests.
  if ! jq -n --arg match_pattern "$match_pattern" '"" | test($match_pattern)' >/dev/null; then
    printf 'fetch_latest_tag: invalid match regex\n' >&2
    return 2
  fi
  if ! jq -n --arg exclude_pattern "$exclude_pattern" '"" | test($exclude_pattern)' >/dev/null; then
    printf 'fetch_latest_tag: invalid exclude regex\n' >&2
    return 2
  fi

  local curl_opts=(-fsSL --connect-timeout 10 --max-time 30)
  if ((proxy_set)); then curl_opts+=(--proxy "$proxy"); fi
  if [[ -n $github_token ]]; then
    curl_opts+=(-H "Authorization: Bearer $github_token")
  fi

  local page=1 response latest
  while ((page <= max_pages)); do
    if ! response=$(curl "${curl_opts[@]}" \
      "https://api.github.com/repos/$repo/tags?per_page=100&page=$page"); then
      printf 'fetch_latest_tag: request failed for %s (page %s)\n' "$repo" "$page" >&2
      return 3
    fi
    if ! latest=$(jq -rs --arg match_pattern "$match_pattern" --arg exclude_pattern "$exclude_pattern" '
      if length != 1 then error("Expected one JSON document") else .[0] end
      |
      if type != "array" then error("Expected a tag array")
      elif any(.[]; if type != "object" then true
                   else (.name | if type != "string" then true else length == 0 end)
                   end) then error("Expected nonempty tag names")
      else first(
        .[] | .name
        | select(test($match_pattern))
        | select(if $exclude_pattern == "" then true else (test($exclude_pattern) | not) end)
      ) // empty
      end
    ' <<<"$response"); then
      printf 'fetch_latest_tag: invalid response for %s (page %s)\n' "$repo" "$page" >&2
      return 3
    fi
    if [[ -n $latest ]]; then
      printf '%s\n' "$latest"
      return 0
    fi
    if jq -e 'length < 100' <<<"$response" >/dev/null; then break; fi
    page=$((page + 1))
  done
  return 1
}
