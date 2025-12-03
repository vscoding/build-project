#!/bin/bash
# shellcheck disable=SC2164,SC2086,SC1090
SHELL_FOLDER=$(cd "$(dirname "$0")" && pwd) && cd "$SHELL_FOLDER"
source git/mirrors.sh

mirror_to_code "devops/build-project"
mirror_to_gitlab "vscoding/build-project"
mirror_to_github "vscoding/build-project"
