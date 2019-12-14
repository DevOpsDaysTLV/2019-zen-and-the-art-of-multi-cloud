#!/bin/bash
# This script is meant to be run in the User Data of each EC2 Instance while it's booting.
set -e

curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && mv ./kubectl /usr/bin/kubectl && chmod 700 /usr/bin/kubectl

apt-get update
apt-get install -y mysql-client
apt-get install -y nginx
echo "Please decompose me!" > /var/www/html/index.nginx-debian.html
sudo apt-get install -y python3-pip
pip3 install --upgrade --user awscli
cp  /root/.local/bin/aws /usr/local/bin

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

cat << EOCCF >/etc/consul.d/client.hcl
advertise_addr = "{{ GetPrivateIP }}"
client_addr =  "0.0.0.0"
data_dir = "/var/lib/consul"
datacenter = "dod_k8s"
enable_syslog = true
log_level = "DEBUG"
retry_join = ["provider=k8s label_selector=\"app=consul,component=server\" kubeconfig=\"/home/ubuntu/kubeconfig\" host_network=true"]
ui = true
EOCCF


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


systemctl daemon-reload
systemctl start consul
