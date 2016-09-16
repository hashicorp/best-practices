#!/bin/bash
set -e

cd /tmp

VAULTVERSION=0.5.0
CONFIGDIR=/ops/$1
SCRIPTSDIR=/ops/$2
VAULTDOWNLOAD=https://releases.hashicorp.com/vault/${VAULTVERSION}/vault_${VAULTVERSION}_linux_amd64.zip
VAULTCONFIGDIR=/etc/vault.d
VAULTDIR=/opt/vault
VAULTPOLICIES=$VAULTDIR/policies
VAULTSCRIPTS=$VAULTDIR/scripts

echo Fetching Vault...
curl -L $VAULTDOWNLOAD > vault.zip

echo Installing Vault...
unzip vault.zip -d /usr/local/bin
chmod 0755 /usr/local/bin/vault
chown root:root /usr/local/bin/vault

echo Creating Vault configuration...
mkdir -p $VAULTCONFIGDIR
chmod 755 $VAULTCONFIGDIR
mkdir -p $VAULTPOLICIES
chmod 755 $VAULTPOLICIES
mkdir -p $VAULTSCRIPTS
chmod 755 $VAULTSCRIPTS

# Consul config
cp $CONFIGDIR/consul/vault.json /etc/consul.d/vault.json

# Vault config
cp $CONFIGDIR/vault/vault.hcl $VAULTCONFIGDIR/vault.hcl

# Vault setup scripts & policies
cp -R $CONFIGDIR/vault/policies/* $VAULTPOLICIES/.
cp -R $CONFIGDIR/vault/scripts/* $VAULTSCRIPTS/.

# Upstart config
cp $SCRIPTSDIR/upstart/vault.conf /etc/init/vault.conf
