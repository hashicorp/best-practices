#!/bin/bash
set -e

cd /tmp

CONSULVERSION=0.6.3
CONFIGDIR=/ops/$1
SCRIPTSDIR=/ops/$2
CONSULDOWNLOAD=https://releases.hashicorp.com/consul/${CONSULVERSION}/consul_${CONSULVERSION}_linux_amd64.zip
CONSULWEBUI=https://releases.hashicorp.com/consul/${CONSULVERSION}/consul_${CONSULVERSION}_web_ui.zip
CONSULCONFIGDIR=/etc/consul.d
CONSULDIR=/opt/consul

echo Fetching Consul...
curl -L $CONSULDOWNLOAD > consul.zip

echo Installing Consul...
unzip consul.zip -d /usr/local/bin
chmod 0755 /usr/local/bin/consul
chown root:root /usr/local/bin/consul

echo Configuring Consul...
mkdir -p $CONSULCONFIGDIR
chmod 755 $CONSULCONFIGDIR
mkdir -p $CONSULDIR
chmod 755 $CONSULDIR

# Consul config
cp $CONFIGDIR/consul/consul_client.json $CONSULCONFIGDIR/base.json

# Upstart config
cp $SCRIPTSDIR/upstart/consul.conf /etc/init/consul.conf

curl -L $CONSULWEBUI > ui.zip
unzip ui.zip -d $CONSULDIR/ui
