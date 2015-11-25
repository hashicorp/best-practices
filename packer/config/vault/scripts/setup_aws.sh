#!/bin/bash
set -e

usage() {
  cat <<EOF
Setup the Vault AWS Secret backend

Prerequisites:

Needs to be run on a node with Vault installed, authenticated, and unsealed.

This script assumes your root-token is stored in Consul KV at /v1/kv/service/vault/

Usage:

  $0 <ACCESS_KEY> <SECRET_KEY> <REGION>

Where ACCESS_KEY is your Vault AWS Access Key ID, SECRET_KEY is your Vault AWS Secret Access Key, and REGION is the AWS region for API calls.
EOF

  exit 1
}

if ! which vault > /dev/null; then
  echo
  echo "ERROR: The vault executable was not found. This script requires vault"
  echo
  usage
fi

ACCESSKEY=$1

if [ -z "${ACCESSKEY}" ]; then
  echo
  echo "ERROR: Specify the Vault AWS Access Key ID as the first argument"
  echo
  usage
fi

SECRETKEY=$2

if [ -z "${SECRETKEY}" ]; then
  echo
  echo "ERROR: Specify the Vault AWS Secret Access Key as the second argument"
  echo
  usage
fi

REGION=$3

if [ -z "${REGION}" ]; then
  echo
  echo "ERROR: Specify the AWS region as the third argument, e.g. us-east-1"
  echo
  usage
fi

if vault status | grep standby > /dev/null; then
  echo "Mounts only run on the leader. Exiting."
  exit 0
fi

echo "Authenticating as root..."

cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }
cget root-token | vault auth -

if vault mounts | grep aws > /dev/null; then
  echo "AWS backend already mounted."
else
  echo "Mounting AWS backend..."
  vault mount aws
fi

echo "Writing root AWS IAM credentials..."

vault write aws/config/root \
  access_key=$ACCESSKEY \
  secret_key=$SECRETKEY \
  region=$REGION

echo "Writing lease settings for generated credentials..."

vault write aws/config/lease \
  lease="1m" \
  lease_max="2m"

shred -u -z ~/.vault-token
