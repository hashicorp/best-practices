#!/bin/bash
set -e

usage() {
  cat <<EOF
Write a Vault role

Prerequisites:

Needs to be run on a node with Vault installed, authenticated, and unsealed.

This script assumes your root-token is stored in Consul KV at /v1/kv/service/vault/

Usage:

  $0 <ROLE_NAME> <POLICY_PATH>

Where ROLE_NAME is the name of the role you wish to create, and POLICY_PATH is the path to the policy for this role.
EOF

  exit 1
}

if ! which vault > /dev/null; then
  echo
  echo "ERROR: The vault executable was not found. This script requires vault"
  echo
  usage
fi

ROLENAME=$1

if [ -z "${ROLENAME}" ]; then
  echo
  echo "ERROR: Specify the name of your role as the first argument, e.g. nodejs/my_app"
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

echo "Authenticating as root..."

cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }
cget root-token | vault auth -

echo "Writing Vault $ROLENAME role..."

vault write aws/roles/$ROLENAME policy=@$POLICYPATH

shred -u -z ~/.vault-token
