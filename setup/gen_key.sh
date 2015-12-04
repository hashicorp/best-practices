#!/bin/bash
set -e

usage() {
  cat <<EOF
Generate a SSL keys

Usage:

  $0 <ENVIRONMENT> **<EXISTING_KEY>**

Where ENVIRONMENT is the Atlas Environment specified in terraform.tfvars. There is an optional second argument you can include that uses an existing private key.

This will generate a .pem private key and a .pub public key in the directory specified.
EOF

  exit 1
}

ENVIRONMENT=$1

if [ "x$ENVIRONMENT" == "x" ]; then
  echo
  echo "ERROR: Specify environment as the second argument, e.g. aws-us-east-1-prod"
  echo
  usage
fi

EXISTINGKEY=$2
KEY=$ENVIRONMENT

if [ -s "$KEY.pem" ] && [ -s "$KEY.pub" ] && [ -z "$EXISTINGKEY" ]; then
  echo Using existing key pair
else
  rm -rf $KEY*

  if [ -z "$EXISTINGKEY" ]; then
    echo No key pair exists and no private key arg was passed, generating new keys...
    openssl genrsa -out $KEY.pem 1024
    chmod 400 $KEY.pem
    ssh-keygen -y -f $KEY.pem > $KEY.pub
  else
    echo Using private key $EXISTINGKEY for key pair...
    cp $EXISTINGKEY $KEY.pem
    chmod 400 $KEY.pem
    ssh-keygen -y -f $KEY.pem > $KEY.pub
  fi

  ssh-add $KEY.pem
fi
