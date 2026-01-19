#!/bin/bash

function image_exists() {
  docker image inspect "$1" >/dev/null 2>&1
}

function volume_exists() {
  docker volume inspect "$1" >/dev/null 2>&1
}
