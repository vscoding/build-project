#!/usr/bin/env bash
set -Eeuo pipefail
# read host and port from input
host=""
function read_host() {
    read -p "Enter host (IP or domain): " host
    if [[ -z "$host" ]]; then
        echo "Host cannot be empty. Please try again."
        read_host
    fi
}

port=""

function read_port() {
  read -p "Enter port: " port
  if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
      echo "Invalid port. Please enter a number between 1 and 65535."
      read_port
  fi
}

read_host
read_port

bash <(curl -sSL https://dev.kubectl.org/linux/network/tcp_connect_ms.sh) "$host" "$port"
