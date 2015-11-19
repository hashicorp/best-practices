#!/bin/bash
set -e

usage() {
  cat <<EOF
Write a Vault role

Prerequisites:

Needs to be run on a node with Vault installed, authenticated, and unsealed.

This script assumes your root-token is stored in Consul KV at /v1/kv/service/vault/

Usage:

  $0 <ROLE_PATH> <POLICY_PATH>

Where ROLE_PATH is the path of the role you wish to create, and POLICY_PATH is the path to the policy for this role.
EOF

  exit 1
}

if ! which vault > /dev/null; then
  echo
  echo "ERROR: The vault executable was not found. This script requires vault"
  echo
  usage
fi

ROLEPATH=$1

if [ -z "${ROLEPATH}" ]; then
  echo
  echo "ERROR: Specify the path of your role as the first argument, e.g. nodejs/my_app"
  echo
  usage
fi

POLICYPATH=$2

if [ -z "${POLICYPATH}" ]; then
  echo
  echo "ERROR: Specify the path to your policy as the second argument, e.g. /opt/vault/policies/aws_nodejs.json"
  echo
  usage
fi

echo "Setting up Vault role..."

cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }

echo "Authenticating as root..."

cget root-token | vault auth -

echo "Writing Vault $ROLEPATH role..."

vault write aws/roles/$ROLEPATH policy=@$POLICYPATH

shred -u -z ~/.vault-token
