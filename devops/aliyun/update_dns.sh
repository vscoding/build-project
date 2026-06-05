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

CURL_SINK="/dev/null"
if is_windows; then
  CURL_SINK="NUL"
fi

DOMAIN_CONFIG_FILE="${1:-${DOMAIN_CONFIG_FILE:-domain_config.json}}"
RETRY_TIMES="${RETRY_TIMES:-3}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required but not installed."
  exit 1
fi

if [ ! -f "$DOMAIN_CONFIG_FILE" ]; then
  echo "domain_config.json not found: $DOMAIN_CONFIG_FILE"
  exit 1
fi

if [ -z "$DNS_API_REQUEST_URL" ] || [ -z "$DNS_TOKEN" ]; then
  echo "DNS_API_REQUEST_URL or DNS_TOKEN is missing in environment"
  exit 1
fi

TOTAL=0
SUCCESS=0
FAILED=0

while IFS=$'\t' read -r domain_name rr record_type record_value; do
  TOTAL=$((TOTAL + 1))
  if [ -z "$record_type" ]; then
    FAILED=$((FAILED + 1))
    log_error "dns-update" "failed: domain=$domain_name rr=$rr type is empty"
    continue
  fi

  if [ -z "$record_value" ]; then
    FAILED=$((FAILED + 1))
    log_error "dns-update" "failed: domain=$domain_name rr=$rr type=$record_type value is empty"
    continue
  fi

  payload=$(jq -n \
    --arg domainName "$domain_name" \
    --arg type "$record_type" \
    --arg rr "$rr" \
    --arg value "$record_value" \
    '{domainName: $domainName, type: $type, rr: $rr, value: $value}')

  attempt=1
  request_ok=0
  while [ $attempt -le $RETRY_TIMES ]; do
    http_code=$(curl -sS -o "$CURL_SINK" -w "%{http_code}" -X POST "$DNS_API_REQUEST_URL" \
      -H "Authorization: Bearer $DNS_TOKEN" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$payload")
    curl_code=$?
    http_code=$(printf '%s' "$http_code" | tr -d '\r\n')

    if [ $curl_code -eq 0 ] && [ "$http_code" = "200" ]; then
      request_ok=1
      break
    fi

    if [ $attempt -lt $RETRY_TIMES ]; then
      log_warn "dns-update" "retry: domain=$domain_name rr=$rr type=$record_type value=$record_value attempt=$attempt/$RETRY_TIMES curl_code=$curl_code http_code=$http_code"
    fi
    attempt=$((attempt + 1))
  done

  if [ $request_ok -eq 1 ]; then
    SUCCESS=$((SUCCESS + 1))
    log_info "dns-update" "ok: domain=$domain_name rr=$rr type=$record_type value=$record_value http_code=$http_code attempts=$attempt"
  else
    FAILED=$((FAILED + 1))
    log_error "dns-update" "failed: domain=$domain_name rr=$rr type=$record_type value=$record_value curl_code=$curl_code http_code=$http_code retries=$RETRY_TIMES"
  fi
done < <(jq -r '.[] | .domain_name as $d | .type as $t | .value as $v | .rr_list[] | [$d, ., $t, $v] | @tsv' "$DOMAIN_CONFIG_FILE" | tr -d '\r')

log_info "dns-update" "finished: total=$TOTAL success=$SUCCESS failed=$FAILED"
