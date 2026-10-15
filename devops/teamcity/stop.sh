#!/usr/bin/env bash
# shellcheck disable=SC2164
SHELL_FOLDER=$(cd "$(dirname "$0")" && pwd)
cd "$SHELL_FOLDER"

export JAVA_HOME=$JAVA_HOME

if [ -d "agent" ]; then
  agent/bin/agent.sh stop
fi

for i in {1..10}; do
  if [ -d "agent$i" ]; then
    agent$i/bin/agent.sh stop
  else
    echo "dir agent$i not exist"
  fi
done
