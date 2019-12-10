#!/bin/bash
#
#

CHECKPOINT_URL="https://checkpoint-api.hashicorp.com/v1/check"
PACKER_VERSION=$(curl -s "${CHECKPOINT_URL}"/packer | jq .current_version | tr -d '"')
TERRAFORM_VERSION=$(curl -s "${CHECKPOINT_URL}"/terraform | jq .current_version | tr -d '"')
CONSUL_VERSION=$(curl -s "${CHECKPOINT_URL}"/consul | jq .current_version | tr -d '"')
NOMAD_VERSION=$(curl -s "${CHECKPOINT_URL}"/nomad | jq .current_version | tr -d '"')
VAULT_VERSION="1.3.0"

# cd /tmp/

# echo "Checking latest Consul and Nomad versions..."
# echo "Fetching Consul version ${CONSUL_VERSION} ..."
# curl -s https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip -o consul.zip
# echo "Installing Consul version ${CONSUL_VERSION} ..."
# unzip consul.zip
# chmod +x consul
# mv consul /usr/local/bin/consul
