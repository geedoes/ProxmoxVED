#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: ProxmoxVED Contributor
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/philippe44/AirConnect

APP="AirConnect"
var_tags="audio;bridge;airplay"
var_cpu="1"
var_ram="512"
var_disk="2"
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/airconnect ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  # Uses tools.func to get the newest release dynamically
  RELEASE=$(get_latest_github_release "philippe44/AirConnect")
  
  if [[ ! -f /opt/airconnect_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/airconnect_version.txt)" ]]; then
    msg_info "Stopping Services"
    systemctl stop airupnp.service
    systemctl stop aircast.service
    msg_ok "Stopped Services"

    msg_info "Updating ${APP} to v${RELEASE}"
    cd /opt/airconnect
    # Fetches the pre-compiled zip payload directly from the master branch per documentation
    wget -q "https://github.com/philippe44/AirConnect/raw/master/AirConnect-${RELEASE}.zip" -O temp.zip
    unzip -q temp.zip
    rm temp.zip
    
    # Identify architecture
    ARCH=$(uname -m)
    BIN_ARCH="linux-x86_64"
    if [ "$ARCH" = "aarch64" ]; then
      BIN_ARCH="linux-aarch64"
    fi
    chmod +x aircast-${BIN_ARCH} airupnp-${BIN_ARCH}
    
    echo "${RELEASE}" > /opt/airconnect_version.txt
    msg_ok "Updated ${APP} to v${RELEASE}"

    msg_info "Starting Services"
    systemctl start airupnp.service
    systemctl start aircast.service
    msg_ok "Started Services"
  else
    msg_ok "No update required. ${APP} is already at v${RELEASE}."
  fi
  exit
}

start
build_container
description
msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} AirConnect services (AirUPnP and AirCast) are running automatically in the background.${CL}"
