#!/usr/bin/env bash
# shellcheck disable=SC2034
sshd_config_file="/etc/ssh/sshd_config"

# 检查配置文件是否存在
if [ ! -f "$sshd_config_file" ]; then
  ssh_port_list=(22)
else
  # 提取所有 Port 行的端口号
  mapfile -t ssh_port_list < <(awk '/^Port[[:space:]]+/{print $2}' "$sshd_config_file")
  # 如果没有配置 Port，则默认 22
  ssh_port_list=("${ssh_port_list[@]:-22}")
fi

# 单独保留第一个端口作为默认
ssh_port=${ssh_port_list[0]}

# 输出
# echo "Default port: $ssh_port"
# echo "All ports: ${ssh_port_list[*]}"

echo "$ssh_port"
