#!/bin/bash
set -e

CONFIGDIR=/ops/$1
SCRIPTSDIR=/ops/$2
VAULTPOLICIES=/opt/vault/policies

echo Installing Node.js...

# Setup a proper node PPA
curl -sL https://deb.nodesource.com/setup | sudo bash -

apt-get -y update
apt-get install -y -qq nodejs

echo Configuring Node.js application...
mkdir -p $VAULTPOLICIES
chmod 755 $VAULTPOLICIES

# Consul config
cp $CONFIGDIR/consul/nodejs.json /etc/consul.d/nodejs.json

# Consul Template config
cp $CONFIGDIR/consul_template/nodejs.hcl /etc/consul_template.d/nodejs.hcl
cp $CONFIGDIR/consul_template/templates/nodejs.ctmpl /opt/consul_template/nodejs.ctmpl

# Vault Policy config
cp $CONFIGDIR/vault/policies/nodejs.json $VAULTPOLICIES/nodejs.json
cp $CONFIGDIR/vault/policies/aws_nodejs.json $VAULTPOLICIES/aws_nodejs.json

# Upstart config
cp $SCRIPTSDIR/upstart/nodejs.conf /etc/init/nodejs.conf
