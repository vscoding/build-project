#!/usr/bin/env bash
# shellcheck disable=SC1090
set -euo pipefail

if [[ -z "${ROOT_URI:-}" ]]; then
  source <(curl -fsSL "https://dev.kubectl.org/init")
fi
export ROOT_URI="${ROOT_URI:-}"

bash <(curl -fsSL "${ROOT_URI}/linux/system/sysctl/bbr.sh")

bash <(curl -fsSL "${ROOT_URI}/linux/system/sysctl/net_opt.sh")

sysctl -p
