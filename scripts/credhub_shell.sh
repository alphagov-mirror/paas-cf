#!/usr/bin/env bash

set -eu

SSH_PATH=${SSH_PATH:-"${HOME}/.ssh/id_rsa"}

tunnel_mux='/tmp/bosh-ssh-tunnel.mux'

function cleanup () {
  echo 'Closing SSH tunnel'
  ssh -S "$tunnel_mux" -O exit a-destination &>/dev/null || true
}
trap cleanup EXIT

USER_ID_RSA="$(base64 "${SSH_PATH}")"
export USER_ID_RSA

BOSH_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:deploy_env,Values=${DEPLOY_ENV}" 'Name=tag:instance_group,Values=bosh' \
    --query 'Reservations[].Instances[].PublicIpAddress' --output text)
export BOSH_IP

ssh -qfNC -4 -D 25555 \
  -o ExitOnForwardFailure=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ServerAliveInterval=30 \
  -M \
  -S "$tunnel_mux" \
  "$BOSH_IP"

# Setup Credhub variables
CREDHUB_CLIENT='credhub-admin'
CREDHUB_SECRET=$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-secrets.yml" - | \
    ruby -ryaml -e 'print YAML.load(STDIN).dig("secrets", "bosh_credhub_admin_client_password")')
CREDHUB_CA_CERT="$(cat <<EOCERTS
$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-vars-store.yml" - | \
  ruby -ryaml -e 'print YAML.load(STDIN).dig("credhub_tls", "ca")')
$(aws s3 cp "s3://gds-paas-${DEPLOY_ENV}-state/bosh-vars-store.yml" - | \
  ruby -ryaml -e 'print YAML.load(STDIN).dig("uaa_ssl", "ca")')
EOCERTS
)"
export CREDHUB_CLIENT CREDHUB_SECRET CREDHUB_CA_CERT

export CREDHUB_SERVER="https://bosh.${SYSTEM_DNS_ZONE_NAME}:8844/api"
export CREDHUB_PROXY="socks5://localhost:25555"

echo "                      ____          __  ";
echo "  _____________  ____/ / /_  __  __/ /_ ";
echo " / ___/ ___/ _ \\/ __  / __ \\/ / / / __ \\";
echo "/ /__/ /  /  __/ /_/ / / / / /_/ / /_/ /";
echo "\\___/_/   \\___/\\____/_/ /_/\\____/_____/ ";
echo "                                        ";

PS1="CREDHUB ($DEPLOY_ENV) $ " bash --login --norc --noprofile

