#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: geedoes
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://ioquake3.org/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y \
  build-essential \
  cmake \
  libsdl2-dev \
  libcurl4-openssl-dev \
  zlib1g-dev \
  pkg-config
msg_ok "Installed Dependencies"

msg_info "Compiling ioquake3 Dedicated Server"
$STD git clone --depth 1 https://github.com/ioquake/ioq3.git /opt/ioq3-src
cd /opt/ioq3-src
mkdir -p build && cd build
$STD cmake -DBUILD_CLIENT=OFF -DBUILD_SERVER=ON ..
$STD make -j$(nproc)
SERVER_BIN=$(find . -maxdepth 2 -type f -name "ioq3ded*" -executable | head -n 1)
if [[ -z "$SERVER_BIN" ]]; then
  msg_error "Compilation finished but ioq3ded binary was not found!"
  exit 1
fi
mkdir -p /opt/ioquake3/baseq3
cp "$SERVER_BIN" /opt/ioquake3/ioq3ded
chmod +x /opt/ioquake3/ioq3ded
rm -rf /opt/ioq3-src
msg_ok "Compiled ioquake3 Dedicated Server"

msg_info "Downloading Latest Patch pk3s"
$STD wget -O /tmp/patch.zip "https://files.ioquake3.org/quake3-latest-pk3s.zip"
$STD unzip /tmp/patch.zip -d /tmp/patch_unzip
cp -a /tmp/patch_unzip/quake3-latest-pk3s/* /opt/ioquake3/
rm -rf /tmp/patch.zip /tmp/patch_unzip
msg_ok "Downloaded Latest Patch pk3s"

msg_info "Creating Server Configuration"
cat <<EOF >/opt/ioquake3/baseq3/server.cfg
seta sv_hostname "Proxmox ioquake3 Server"
seta sv_maxclients 16
seta g_motd "Welcome to ioquake3 LXC!"
seta g_quadfactor 3
seta g_gametype 0
seta timelimit 15
seta fraglimit 20
seta g_weaponrespawn 5
seta g_inactivity 3000
seta g_forcerespawn 0
seta g_log "games.log"
seta logfile 1
seta rconpassword "changeme"
seta com_legacyprotocol 68
map q3dm17
EOF
msg_ok "Created Server Configuration"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/ioquake3.service
[Unit]
Description=ioquake3 Dedicated Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/ioquake3
ExecStart=/opt/ioquake3/ioq3ded +set dedicated 1 +set com_hunkMegs 128 +set net_port 27960 +exec server.cfg
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now ioquake3
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
