#!/usr/bin/env bash

# 判断是不是windows
function is_windows() {
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    return 0
  else
    return 1
  fi
}
