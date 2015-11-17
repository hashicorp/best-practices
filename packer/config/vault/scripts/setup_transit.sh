#!/bin/bash
set -e

usage() {
  cat <<EOF
Setup the Vault Transit backend

Prerequisites:

Needs to be run on a node with Vault installed, authenticated, and unsealed.
This script assumes your root-token is stored in Consul KV at /v1/kv/service/vault/
EOF

  exit 1
}

if ! which vault > /dev/null; then
  echo
  echo "ERROR: The vault executable was not found. This script requires vault"
  echo
  usage
fi

if vault status | grep standby > /dev/null; then
  echo "Mounts only run on the leader. Exiting."
  exit 0
fi

echo "Mounting Transit backend."

cget root-token | vault auth -

if vault mounts | grep transit > /dev/null; then
  echo "Transit backend already mounted. Exiting."
  shred -u -z ~/.vault-token
  exit 0
fi

vault mount transit

shred -u -z ~/.vault-token
