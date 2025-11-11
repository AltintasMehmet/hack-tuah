#!/bin/bash
set -euxo pipefail

# Environment variables
cat <<'VAREOF' >/etc/profile.d/playlistparser-frontend.sh
%{ for key, value in environment_variables ~}
export ${key}="${value}"
%{ endfor ~}
VAREOF

source /etc/profile.d/playlistparser-frontend.sh

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx git curl

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

cd "$SOURCE_DIR/frontend"
npm install
npm run build

rm -rf /var/www/html/*
cp -r dist/* /var/www/html/

cat <<'NGINX' >/etc/nginx/sites-available/playlistparser
server {
    listen ${port};
    server_name _;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location = /healthz {
        access_log off;
        add_header Content-Type text/plain;
        return 200 'ok';
    }
}
NGINX

ln -sf /etc/nginx/sites-available/playlistparser /etc/nginx/sites-enabled/playlistparser
rm -f /etc/nginx/sites-enabled/default
systemctl enable nginx
systemctl restart nginx

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
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "${environment}-playlistparser-frontend",
            "log_stream_name": "nginx-access"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "${environment}-playlistparser-frontend",
            "log_stream_name": "nginx-error"
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
