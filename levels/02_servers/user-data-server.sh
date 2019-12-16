#!/bin/bash
# This script is meant to be run in the User Data of each EC2 Instance while it's booting.
set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

cat << EOCCF >/etc/consul.d/server.hcl
advertise_addr = "{{ GetPrivateIP }}"
bootstrap_expect = 3
client_addr =  "0.0.0.0"
data_dir = "/var/lib/consul"
datacenter = "${cluster_tag_value}"
enable_syslog = true
log_level = "DEBUG"
retry_join = ["provider=aws tag_key=${cluster_tag_key} tag_value=${cluster_tag_value}"]
server = true
ui = true
EOCCF

cat << EONCF >/etc/nomad.d/server.hcl
bind_addr          = "0.0.0.0"
region             = "${cluster_tag_value}"
datacenter         = "${cluster_tag_value}"
data_dir           = "/var/lib/nomad/"
log_level          = "DEBUG"
leave_on_interrupt = true
leave_on_terminate = true
server {
  enabled          = true
  bootstrap_expect = 3
}
EONCF

cat << EOVCF >/etc/vault.d/server.hcl
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
EOVCF

cat << EOCSU >/etc/systemd/system/consul.service
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target
[Service]
LimitNOFILE=65536
Restart=on-failure
ExecStart=/usr/local/bin/consul agent -config-dir /etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
Type=notify
[Install]
WantedBy=multi-user.target
EOCSU

cat << EONSU >/etc/systemd/system/nomad.service
[Unit]
Description=nomad agent
Requires=network-online.target consul.service
After=network-online.target consul.service
[Service]
LimitNOFILE=65536
Restart=on-failure
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
KillSignal=SIGINT
RestartSec=5s
[Install]
WantedBy=multi-user.target
EONSU

cat << EOVSU >/etc/systemd/system/vault.service
[Unit]
Description=Vault
Requires=network-online.target consul.service
After=network-online.target consul.service

[Service]
LimitNOFILE=65536
LimitMEMLOCK=infinity
TaskMax=infinity
Restart=on-failure
ExecStart=/usr/local/bin/vault server -config /etc/vault.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
RestartSec=5s
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes

[Install]
WantedBy=multi-user.target
EOVSU

systemctl daemon-reload
systemctl start consul
systemctl start nomad
systemctl start vault
