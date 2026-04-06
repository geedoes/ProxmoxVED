#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: geedoes
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://ioquake3.org/

# --- Standard Header ---
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
    build-essential \
    git \
    libsdl2-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    pkg-config \
    unzip \
    curl
msg_ok "Installed Dependencies"

msg_info "Compiling ioquake3 Dedicated Server"
# Clone to a temporary build location
git clone --depth 1 https://github.com/ioquake/ioq3.git /opt/ioq3-src
cd /opt/ioq3-src

# Compile using the Makefile (standard for ioq3)
# We disable the client to keep the LXC lightweight
$STD make -j$(nproc) BUILD_CLIENT=0 BUILD_SERVER=1

# Identify the release folder (varies by architecture, e.g., release-linux-x86_64)
RELEASE_DIR=$(ls -d build/release-linux-* | head -n 1)

if [ -z "$RELEASE_DIR" ]; then
  msg_error "Compilation failed: No release directory found."
  exit 1
fi

# Move the ACTUAL compiled artifacts to the permanent home
mkdir -p /opt/ioquake3
cp -rf "$RELEASE_DIR"/* /opt/ioquake3/
msg_ok "Compiled and Installed to /opt/ioquake3"

msg_info "Downloading Latest Patch pk3s"
# ioquake3 requires the original data files or the latest patch pk3s to run
$STD wget -qO /tmp/patch.zip "https://files.ioquake3.org/quake3-latest-pk3s.zip"
mkdir -p /tmp/patch_unzip
$STD unzip -q /tmp/patch.zip -d /tmp/patch_unzip
# Move patches into the baseq3 folder
cp -rf /tmp/patch_unzip/quake3-latest-pk3s/* /opt/ioquake3/
msg_ok "Downloaded Latest Patch pk3s"

msg_info "Creating Server Configuration"
RCON_PASS=$(openssl rand -hex 12)
mkdir -p /opt/ioquake3/baseq3
cat <<EOF >/opt/ioquake3/baseq3/server.cfg
seta sv_hostname "Proxmox ioquake3 Server"
seta sv_maxclients 16
seta g_motd "Welcome to ioquake3 LXC!"
seta rconpassword "$RCON_PASS"
seta com_hunkMegs 128
seta net_port 27960
seta com_legacyprotocol 68
map q3dm17
EOF
msg_ok "Created Configuration (RCON: $RCON_PASS)"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/ioquake3.service
[Unit]
Description=ioquake3 Dedicated Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ioquake3
# We target the specific architecture-named binary
ExecStart=/bin/sh -c '/opt/ioquake3/ioq3ded.$(uname -m) +set dedicated 1 +exec server.cfg'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now ioquake3
msg_ok "Created Service"

msg_info "Cleanup"
# Remove the source and build artifacts now that the binary is moved
rm -rf /opt/ioq3-src /tmp/patch.zip /tmp/patch_unzip

# Purge build-only tools to follow AI.md "Slim LXC" guidelines
$STD apt-get purge -y build-essential git unzip
$STD apt-get autoremove -y

# Final ProxmoxVED library cleanup
cleanup_lxc
msg_ok "Cleanup Completed"

motd_ssh
customize
