#!/usr/bin/env bash

os_release="/etc/os-release"

if [ ! -f $os_release ]; then
  echo "unknown"
  exit
fi

. /etc/os-release && echo "$NAME"
