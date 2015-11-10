#!/bin/bash
set -e

usage() {
  cat <<EOF
Generate a Vault policy

Prerequisites:

Needs to be run on a node with Vault installed, authenticated, and unsealed.
This script assumes your root-token is stored in Consul KV at /v1/kv/service/vault/

Usage:

  $0 <NAME>

Where NAME is the name of the policy you wish to create.
EOF

  exit 1
}

if ! which vault > /dev/null; then
  echo
  echo "ERROR: The vault executable was not found. This script requires vault"
  echo
  usage
fi

NAME=$1

if [ -z "$NAME" ]; then
  echo
  echo "ERROR: Specify the name of your policy as the first argument, e.g. nodejs_app"
  echo
  usage
fi

echo "Setting up Vault policy"

cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }

echo "Authenticating as root..."
cget root-token | vault auth -

echo "Writing Vault $NAME policy..."
vault policy-write "$NAME" /opt/vault/policies/$NAME.hcl
