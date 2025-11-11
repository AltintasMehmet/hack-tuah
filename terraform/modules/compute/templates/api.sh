#!/bin/bash
set -euxo pipefail

# Environment variables
cat <<'VAREOF' >/etc/profile.d/playlistparser-api.sh
%{ for key, value in environment_variables ~}
export ${key}="${value}"
%{ endfor ~}
VAREOF

source /etc/profile.d/playlistparser-api.sh

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y git curl build-essential

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs
fi

mkdir -p /opt/playlistparser
cd /opt/playlistparser

: "${APP_SOURCE_URL:?APP_SOURCE_URL must be provided}"
SOURCE_DIR="/opt/playlistparser/source"
if [ ! -d "$SOURCE_DIR/.git" ]; then
  rm -rf "$SOURCE_DIR"
  git clone "$APP_SOURCE_URL" "$SOURCE_DIR"
else
  cd "$SOURCE_DIR"
  git reset --hard HEAD || true
  git pull --rebase || true
fi

cd "$SOURCE_DIR/api"
npm install
npm run build || true

cat <<'SERVICE' >/etc/systemd/system/playlistparser-api.service
[Unit]
Description=PXL Playlist Parser API
After=network.target

[Service]
EnvironmentFile=/etc/playlistparser-api.env
WorkingDirectory=/opt/playlistparser/api
ExecStart=/usr/bin/node server.js
Restart=on-failure
StandardOutput=append:/var/log/playlistparser-api.log
StandardError=append:/var/log/playlistparser-api.log

[Install]
WantedBy=multi-user.target
SERVICE

cat <<'ENVFILE' >/etc/playlistparser-api.env
PORT=${port}
%{ for key, value in environment_variables ~}
${key}="${value}"
%{ endfor ~}
ENVFILE

systemctl daemon-reload
systemctl enable playlistparser-api.service
systemctl restart playlistparser-api.service

%{ if enable_cloudwatch_agent }
apt-get install -y amazon-cloudwatch-agent || true
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a stop || true
cat <<CWAGENT >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/playlistparser-api.log",
            "log_group_name": "${environment}-playlistparser-api",
            "log_stream_name": "api"
          }
        ]
      }
    }
  }
}
CWAGENT

systemctl enable amazon-cloudwatch-agent || true
systemctl restart amazon-cloudwatch-agent || true
%{ endif }
