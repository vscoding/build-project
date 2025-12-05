#!/bin/bash
# shellcheck disable=SC1090,SC2086,SC2028,SC2162
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)
# ROOT_URI=https://dev.kubectl.net

source <(curl -sSL $ROOT_URI/func/log.sh)
current_dir=$(pwd)

read -p "Confirm init liquibase in [$current_dir] (y/n)" confirm

function init_liquibase() {
  log_warn "rm" "rm -rf db/"
  rm -rf db/

  log_info "mkdir" "mkdir -p db/changelog"
  mkdir -p db/changelog
  log_info "mkdir" "mkdir -p db/changelog/records"
  mkdir -p db/changelog/records

  cat >db/changelog/db.changelog-master.yaml <<EOF
databaseChangeLog:
  - includeAll:
      path: db/changelog/records
      resourceComparator: "false"
EOF

  cat >db/changelog/records/init.sql <<EOF
-- liquibase formatted sql

EOF
}

if [ "y" == "$confirm" ]; then
  init_liquibase
else
  log_info "confirm" "No Confirm"
  exit
fi
