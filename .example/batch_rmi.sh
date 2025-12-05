#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

registry="docker.io"
image_name_list=("hello" "world")

# 使用 for 循环来遍历数组中的每个元素
for image_name in "${image_name_list[@]}"; do
  echo "remove image is : $registry/$image_name"
  bash <(curl -sSL $ROOT_URI/docker/rmi.sh) \
    -i "$registry/$image_name" \
    -s "contain_latest"
done
