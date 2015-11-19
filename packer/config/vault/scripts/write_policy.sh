#!/bin/bash
set -e

usage() {
  cat <<EOF
Write a Vault policy

Prerequisites:

Needs to be run on a node with Vault installed, authenticated, and unsealed.

This script assumes your root-token is stored in Consul KV at /v1/kv/service/vault/

Usage:

  $0 <POLICY_NAME> <POLICY_PATH>

Where POLICY_NAME is the name of the policy you wish to create, and POLICY_PATH is the path to the policy.
EOF

  exit 1
}

if ! which vault > /dev/null; then
  echo
  echo "ERROR: The vault executable was not found. This script requires vault"
  echo
  usage
fi

POLICYNAME=$1

if [ -z "${POLICYNAME}" ]; then
  echo
  echo "ERROR: Specify the name of your policy as the first argument, e.g. nodejs"
  echo
  usage
fi

POLICYPATH=$2

if [ -z "${POLICYPATH}" ]; then
  echo
  echo "ERROR: Specify the path to your policy as the second argument, e.g. /opt/vault/policies/nodejs.hcl"
  echo
  usage
fi

echo "Authenticating as root..."

cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }
cget root-token | vault auth -

echo "Writing Vault $POLICYNAME policy..."

vault policy-write "${POLICYNAME}" $POLICYPATH

shred -u -z ~/.vault-token
