#!/bin/bash
# shellcheck disable=SC2164
SHELL_FOLDER=$(cd "$(dirname "$0")" && pwd)
cd "$SHELL_FOLDER"

LOCK_PATH="$SHELL_FOLDER/test.lock"

function kill_process() {
  (
    flock -x 9 || exit 1

    echo "kill_process"

  ) 9>"$LOCK_PATH"
}

function run_process() {
  (
    flock -x 9 || exit 1
    # 这是一个启动后台服务的函数，后台服务的运行不需要持有锁
    echo "run_process"

    flock -u 9 # 这里需要手动释放锁，否则后台服务也会长期持有锁
  ) 9>"$LOCK_PATH"
}

function restart_process() {
  (
    # kill_process函数是带锁执行的，但执行后会自动释放锁
    kill_process

    # kill后，这里重新加锁
    flock -x 9 || exit 1

    # 这是一个启动后台服务的函数，后台服务的运行不需要持有锁
    echo "restart_process"

    # 这里需要手动释放锁，否则后台服务也会长期持有锁
    flock -u 9
  ) 9>"$LOCK_PATH"
}

restart_process
