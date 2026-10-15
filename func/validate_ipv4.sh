#!/usr/bin/env bash

function validate_ipv4() {
  local ip=$1
  local regex='^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'

  if [[ $ip =~ $regex ]]; then
    log_info "validate_ip" "Valid IP"
  else
    log_error "validate_ip" "Invalid IP"
    return 1
  fi
}
