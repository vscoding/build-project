#!/bin/bash
# shellcheck disable=SC2115 disable=SC2162 disable=SC2086
read -r -p "use taos default dir config? (y/n): " useDefault

if [ "$useDefault" == "y" ]; then
  log_dir="/var/log/taos"
  data_dir="/var/lib/taos"
else
  read -r -p "请输入日志目录: " log_dir
  if [ -z $log_dir ]; then
    log_dir="/data/persistence/taos/log"
    echo "日志目录默认为 $log_dir"
  fi
  read -r -p "请输入数据目录: " data_dir
  if [ -z $data_dir ]; then
    data_dir="/data/persistence/taos/data"
    echo "数据目录默认为 $data_dir"
  fi
fi

function clean_data_log() {
  if [ -d $log_dir ]; then
    read -r -p "是否清空日志目录 $log_dir? (y/n): " cleanLog
    if [ "$cleanLog" == "y" ]; then
      rm -rf $log_dir/*
      echo "日志目录 $log_dir 已清空"
    fi
  else
    echo "日志目录 $log_dir 不存在"
    mkdir -p $log_dir
  fi

  if [ -d $data_dir ]; then
    read -r -p "是否清空数据目录 $data_dir? (y/n): " cleanData
    if [ "$cleanData" == "y" ]; then
      rm -rf $data_dir/*
      echo "数据目录 $data_dir 已清空"
    fi
  else
    echo "数据目录 $data_dir 不存在"
    mkdir -p $data_dir
  fi
}

read -r -p "是否清空数据和日志目录? (y/n): " cleanAll
if [ "$cleanAll" == "y" ]; then
  clean_data_log
else
  echo "未清空数据和日志目录"
fi
