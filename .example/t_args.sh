#!/bin/bash
# shellcheck disable=SC2164
SHELL_FOLDER=$(cd "$(dirname "$0")" && pwd)
cd "$SHELL_FOLDER"

args=(
  "--arg1" "value1"
  "--arg2" "value with spaces"
  "--flag" "true"
  "--number" "42"
)

# shellcheck disable=SC2145
echo "Arguments received: ${args[@]}"