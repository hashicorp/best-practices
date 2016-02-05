#!/bin/bash
set -e

cd /tmp

CTVERSION=0.12.2
CONFIGDIR=/ops/$1
SCRIPTSDIR=/ops/$2
CTDOWNLOAD=https://releases.hashicorp.com/consul-template/${CTVERSION}/consul-template_${CTVERSION}_linux_amd64.zip
CTCONFIGDIR=/etc/consul_template.d
CTDIR=/opt/consul_template

echo Fetching Consul Template...
curl -L $CTDOWNLOAD > consul_template.zip

echo Installing Consul Template...
unzip consul_template.zip -d /usr/local/bin
chmod 0755 /usr/local/bin/consul-template
chown root:root /usr/local/bin/consul-template

echo Configuring Consul Template...
mkdir -p $CTCONFIGDIR
chmod 755 $CTCONFIGDIR
mkdir -p $CTDIR
chmod 755 $CTDIR

# Consul Template config
cp $CONFIGDIR/consul_template/base.hcl $CTCONFIGDIR/base.hcl

# Upstart config
cp $SCRIPTSDIR/upstart/consul_template.conf /etc/init/consul_template.conf
