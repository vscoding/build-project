#!/bin/bash
# shellcheck disable=SC1090 disable=SC2086 disable=SC2155 disable=SC2128 disable=SC2028  disable=SC2317  disable=SC2164
[ -z $ROOT_URI ] && source <(curl -sSL https://dev.kubectl.org/init)

source <(curl -sSL $ROOT_URI/func/log.sh)
source <(curl -sSL $ROOT_URI/func/command_exists.sh)

function prepare() {
  if ! command_exists wget; then
    log_error "prepare" "command curl does not exist"
    return 1
  fi

  if ! command_exists unzip; then
    log_error "prepare" "command unzip does not exist"
    return 1
  fi

  source /etc/profile
  source $HOME/.bashrc
  if [ -z $JAVA_HOME ]; then
    log_error "prepare" "JAVA_HOME is not set"
    retrun 1
  else
    log_info "prepare" "JAVA_HOME is $JAVA_HOME"

    # sure use this JAVA_HOME
    read -p "Enter y to continue use JAVA_HOME $JAVA_HOME :" confirm
    if [ "$confirm" != "y" ]; then
      read -p "Enter the JAVA_HOME path: " JAVA_HOME
      if [ -z $JAVA_HOME ]; then
        log_error "prepare" "JAVA_HOME is empty"
        return 1
      else
        log_info "prepare" "JAVA_HOME is $JAVA_HOME"
      fi
    fi
  fi
  return 0
}

function remove_systemd() {
  function try_stop_teamcity_agent_systemd() {
    if [ -f "/usr/lib/systemd/system/teamcity-agent.service" ] || [ -f "/etc/systemd/system/teamcity-agent.service" ]; then
      log_info "teamcity" "stop teamcity-agent service"
      systemctl stop teamcity-agent
      log_info "teamcity" "disable teamcity-agent service"
      systemctl disable teamcity-agent
      log_info "teamcity" "reload systemd"
      systemctl daemon-reload

      log_info "teamcity" "remove teamcity-agent service"
      rm -rf /usr/lib/systemd/system/teamcity-agent.service
      rm -rf /etc/systemd/system/teamcity-agent.service
    else
      log_info "teamcity" "teamcity-agent.service is not exist"
    fi
  }

  function try_stop_teamcity_agents_systemd() {
    if [ -f "/usr/lib/systemd/system/teamcity-agent@.service" ] || [ -f "/etc/systemd/system/teamcity-agent@.service" ]; then
      for ((i = 1; i <= 16; i++)); do
        log_info "teamcity" "stop teamcity-agent@$i service"
        systemctl stop teamcity-agent@$i
        log_info "teamcity" "disable teamcity-agent@$i service"
        systemctl disable teamcity-agent@$i
        log_info "teamcity" "reload systemd"
      done
      systemctl daemon-reload
      log_info "teamcity" "remove teamcity-agent@.service"
      rm -rf /usr/lib/systemd/system/teamcity-agent@.service
      rm -rf /etc/systemd/system/teamcity-agent@.service
    else
      log_info "teamcity" "teamcity-agent@.service is not exist"
    fi

  }

  try_stop_teamcity_agent_systemd
  try_stop_teamcity_agents_systemd
}

function download_teamcity_agent() {
  function read_download_server() {
    read -p "Enter the teamcity server: " teamcity_server
    if [ -z $teamcity_server ]; then
      log_error "teamcity" "teamcity server is empty"
      read_download_server
    else
      log_info "teamcity" "teamcity server is $teamcity_server"
    fi
  }
  read_download_server

  function read_install_path() {
    read -p "Enter the teamcity agent install path (default is /opt/teamcity-agent) :" teamcity_agent_path
    if [ -z $teamcity_agent_path ]; then
      teamcity_agent_path="/opt/teamcity-agent"
      log_info "teamcity" "use default teamcity agent install path: $teamcity_agent_path"
    else
      log_info "teamcity" "teamcity agent install path is $teamcity_agent_path"
    fi
  }
  read_install_path

  read -p "Enter y to continue install teamcity agent in $teamcity_agent_path :" confirm
  if [ "$confirm" != "y" ]; then
    log_error "teamcity" "exit install teamcity agent"
    return 1
  fi

  if [ -d $teamcity_agent_path ]; then
    log_warn "teamcity" "teamcity agent install path $teamcity_agent_path is exist"
    log_warn "teamcity" "teamcity agent maybe exist, try stop and remove"

    read -p "Enter y to continue remove $teamcity_agent_path :" confirm
    if [ "$confirm" != "y" ]; then
      log_warn "teamcity" "exit remove teamcity agent"
      return 1
    fi

    remove_systemd

    log_info "teamcity" "remove teamcity agent install path $teamcity_agent_path"
    rm -rf $teamcity_agent_path
    log_info "teamcity" "create teamcity agent install path $teamcity_agent_path"
    mkdir -p $teamcity_agent_path
  else
    log_info "teamcity" "create teamcity agent install path $teamcity_agent_path"
    mkdir -p $teamcity_agent_path
  fi

  # 下载teamcity-agent
  wget $teamcity_server/update/buildAgentFull.zip -O $teamcity_agent_path/buildAgentFull.zip
  if unzip -t "$teamcity_agent_path/buildAgentFull.zip" &>/dev/null; then
    log_info "teamcity" "The file $teamcity_agent_path/buildAgentFull.zip is a valid zip file."
    return 0
  else
    log_error "teamcity" "The file $teamcity_agent_path/buildAgentFull.zip is not a valid zip file."
    return 1
  fi
}
