#!/bin/bash
# shellcheck disable=SC1090 disable=SC2181
set -euo pipefail
# 初始化根URI和依赖
[ -z "${ROOT_URI:-}" ] && source <(curl -sSL https://dev.kubectl.org/init)
source <(curl -sSL "$ROOT_URI/func/log.sh")

log "test" "This is a test script. It does not perform any actions."
