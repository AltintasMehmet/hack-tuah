#!/bin/bash
set -euxo pipefail

devicename="/dev/xvdf"
mountpoint="/var/lib/postgresql"

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql postgresql-contrib lvm2 amazon-cloudwatch-agent xfsprogs rsync

PG_VERSION=$(psql -V | awk '{print $3}' | cut -d. -f1)
PG_CONF_DIR="/etc/postgresql/${PG_VERSION}/main"
PG_DATA_DIR="/var/lib/postgresql/${PG_VERSION}/main"

if [ ! -e "$devicename" ]; then
  devicename="/dev/nvme1n1"
fi

if ! blkid "$devicename" >/dev/null 2>&1; then
  mkfs.xfs "$devicename"
fi

mkdir -p "$mountpoint"
if ! mountpoint -q "$mountpoint"; then
  mount "$devicename" "$mountpoint"
fi

if ! grep -q "$mountpoint" /etc/fstab; then
  uuid=$(blkid -s UUID -o value "$devicename")
  echo "UUID=$uuid $mountpoint xfs defaults,nofail 0 2" >>/etc/fstab
fi

chown -R postgres:postgres "$mountpoint"
chmod 700 "$mountpoint"

systemctl stop postgresql
if [ -d "$PG_DATA_DIR" ] && [ ! -L "$PG_DATA_DIR" ]; then
  rsync -a "$PG_DATA_DIR"/ "$mountpoint"/
  rm -rf "$PG_DATA_DIR"
  ln -s "$mountpoint" "$PG_DATA_DIR"
fi
systemctl start postgresql

sudo -u postgres psql <<SQL
DO
$$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${db_username}') THEN
      CREATE ROLE ${db_username} LOGIN PASSWORD '${db_password}';
   END IF;
END
$$;

CREATE DATABASE playlistparser OWNER ${db_username};
GRANT ALL PRIVILEGES ON DATABASE playlistparser TO ${db_username};
SQL

cat <<CONF >${PG_CONF_DIR}/pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
host    playlistparser  ${db_username}  10.0.0.0/8              md5
CONF

if ! grep -q "^listen_addresses" "${PG_CONF_DIR}/postgresql.conf"; then
  echo "listen_addresses = '*'" >>"${PG_CONF_DIR}/postgresql.conf"
fi

systemctl restart postgresql

cat <<CWAGENT >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/postgresql/postgresql-${PG_VERSION}-main.log",
            "log_group_name": "${environment}-playlistparser-database",
            "log_stream_name": "postgres"
          }
        ]
      }
    }
  }
}
CWAGENT

systemctl enable amazon-cloudwatch-agent
systemctl restart amazon-cloudwatch-agent

cat <<'HEALTH' >/usr/local/bin/db-healthz.sh
#!/bin/bash
pg_isready -h localhost -p 5432
HEALTH
chmod +x /usr/local/bin/db-healthz.sh
