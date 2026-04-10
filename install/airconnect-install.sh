#!/usr/bin/env bash
# Copyright (c) 2021-2026 community-scripts ORG
# Author: ProxmoxVED Contributor
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/philippe44/AirConnect

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
# Unzip is needed for the payload; libssl-dev prevents missing SSL library warnings on older devices
$STD apt-get install -y \
  curl \
  wget \
  unzip \
  libssl-dev
msg_ok "Installed Dependencies"

msg_info "Installing AirConnect"
RELEASE=$(get_latest_github_release "philippe44/AirConnect")
mkdir -p /opt/airconnect
cd /opt/airconnect

wget -q "https://github.com/philippe44/AirConnect/raw/master/AirConnect-${RELEASE}.zip" -O airconnect.zip
unzip -q airconnect.zip
rm airconnect.zip

# Architecture mapping fallback
ARCH=$(uname -m)
BIN_ARCH="linux-x86_64"
if [ "$ARCH" = "aarch64" ]; then
  BIN_ARCH="linux-aarch64"
fi

chmod +x aircast-${BIN_ARCH} airupnp-${BIN_ARCH}

echo "${RELEASE}" > /opt/airconnect_version.txt
msg_ok "Installed AirConnect"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/airupnp.service
[Unit]
Description=AirUPnP Bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
# '-Z' acts natively to suppress standard interactive CLI while preventing demonizing, allowing Systemd to track properly
ExecStart=/opt/airconnect/airupnp-${BIN_ARCH} -Z
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/aircast.service
[Unit]
Description=AirCast Bridge
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/airconnect/aircast-${BIN_ARCH} -Z
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now airupnp.service
systemctl enable -q --now aircast.service
msg_ok "Created Services"

motd_ssh
customize
cleanup_lxc
