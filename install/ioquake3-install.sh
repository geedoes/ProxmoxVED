#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: geedoes
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://ioquake3.org/

# --- Standard Header & Environment Setup ---
# The DETAILED_GUIDE.md emphasizes loading functions before any execution
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
# Standard ProxmoxVED practice: Use $STD to keep logs clean unless debugging
$STD apt-get install -y \
    build-essential \
    git \
    cmake \
    libsdl2-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    pkg-config \
    unzip
msg_ok "Installed Dependencies"

msg_info "Compiling ioquake3 Dedicated Server"
# Guidelines recommend /opt for third-party source builds that are later cleaned
git clone --depth 1 https://github.com/ioquake/ioq3.git /opt/ioq3-src
cd /opt/ioq3-src
mkdir -p build && cd build

# Optimization: Building only the server binary for LXC efficiency per AI.md tips
# Using $STD here ensures the long compilation output doesn't clutter the Proxmox UI
$STD cmake -DBUILD_CLIENT=OFF -DBUILD_SERVER=ON ..
$STD make -j$(nproc)

# Locate binary - using a more robust search per script standards
SERVER_BIN=$(find . -maxdepth 3 -type f -name "ioq3ded*" -executable | head -n 1)
if [[ -z "$SERVER_BIN" ]]; then
  msg_error "Compilation failed: ioq3ded binary not found."
  exit 1
fi

mkdir -p /opt/ioquake3/baseq3
cp "$SERVER_BIN" /opt/ioquake3/ioq3ded
chmod +x /opt/ioquake3/ioq3ded
msg_ok "Compiled ioquake3 Dedicated Server"

msg_info "Downloading Latest Patch pk3s"
# Detailed Guide suggests using /tmp for transient downloads
$STD wget -qO /tmp/patch.zip "https://files.ioquake3.org/quake3-latest-pk3s.zip"
mkdir -p /tmp/patch_unzip
$STD unzip -q /tmp/patch.zip -d /tmp/patch_unzip
cp -a /tmp/patch_unzip/quake3-latest-pk3s/* /opt/ioquake3/
msg_ok "Downloaded Latest Patch pk3s"

msg_info "Creating Server Configuration"
# Standard Practice: Generate secrets during install, not hardcoded
RCON_PASS=$(openssl rand -hex 12)
cat <<EOF >/opt/ioquake3/baseq3/server.cfg
seta sv_hostname "Proxmox ioquake3 Server"
seta sv_maxclients 16
seta g_motd "Welcome to ioquake3 LXC!"
seta rconpassword "$RCON_PASS"
seta com_legacyprotocol 68
map q3dm17
EOF
msg_ok "Created Server Configuration (RCON: $RCON_PASS)"

msg_info "Creating Service"
# Systemd best practices from the docs: Ensure User=root is explicit if needed, 
# or a dedicated user if the app allows.
cat <<EOF >/etc/systemd/system/ioquake3.service
[Unit]
Description=ioquake3 Dedicated Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/ioquake3
ExecStart=/opt/ioquake3/ioq3ded +set dedicated 1 +set com_hunkMegs 128 +set net_port 27960 +exec server.cfg
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now ioquake3
msg_ok "Created and Started Service"

# --- Cleanup & Finalization ---
# AI.md/DETAILED_GUIDE highlight the importance of "Cleanup" to keep LXC images small
msg_info "Cleanup"
rm -rf /opt/ioq3-src /tmp/patch.zip /tmp/patch_unzip
$STD apt-get purge -y build-essential cmake git
$STD apt-get autoremove -y
msg_ok "Cleanup Completed"

# Standard ProxmoxVED footer functions
motd_ssh
customize
cleanup_lxc
