#!/bin/bash

set -e

usage() {
  cat <<EOF
Generate a SSL keys

Usage:

  $0 <ENVIRONMENT> [EXISTING KEY]

Where ENVIRONMENT is the Atlas Environment specified in terraform.tfvars. There
is an optional second argument you can include that uses an existing private
key.

This will generate a .pem private key and a .pub public key in the directory
specified.
EOF
}

main() {
  local environment="$1"
  local existingkey="$2"
  local key="$environment"

  if [[ -z "$environment" || $# -eq 0 ]]; then
    printf "ERROR: Specify environment as the second argument, e.g. aws-us-east-1-prod\n\n" >&2
    usage
    exit 1
  fi

  if [[ -s "$key.pem" && -s "$key.pub" && -z "$existingkey" ]]; then
    echo "Using existing key pair"
    return 0
  fi

  umask 277

  if [[ -z "$existingkey" ]]; then
    echo "No key pair exists and no private key arg was passed, generating new keys..."
    rm -f "${key}.pem"
    openssl genrsa -out "$key.pem" 1024

  elif [[ -s "$existingkey" ]]; then
    echo "Using private key $existingkey for key pair..."
    cp "$existingkey" "$key.pem"

  else
    echo "ERROR: Missing or empty existing private key $existingkey!"
    exit 1
  fi

  rm -f "${key}.pub"
  ssh-keygen -y -f "$key.pem" > "$key.pub"
}

main "$@"

