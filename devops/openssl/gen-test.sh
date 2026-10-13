#!/bin/bash
# shellcheck disable=SC2164,SC1090,SC2086
SHELL_FOLDER=$(cd "$(dirname "$0")" && pwd) && cd "$SHELL_FOLDER"

CERT_CN="default.invalid" \
  CERT_SAN_DNS="default.invalid, fallback.invalid, localhost" \
  CERT_SAN_IP="127.0.0.1,::1" \
  bash ./generate-test-cert.sh
