#!/bin/bash
set -e

CONFIGDIR=/ops/$1
SCRIPTSDIR=/ops/$2
RSYSLOG=/etc/rsyslog.conf

echo Installing HAProxy...

apt-get -y update
apt-get install -y haproxy
chmod a+w /etc/rsyslog.conf

echo '$ModLoad imudp' >> $RSYSLOG
echo '$UDPServerAddress 127.0.0.1' >> $RSYSLOG
echo '$UDPServerRun 514' >> $RSYSLOG

echo Configuring HAProxy...

# Consul config
cp $CONFIGDIR/consul/haproxy.json /etc/consul.d/haproxy.json

# Consul Template config
cp $CONFIGDIR/consul_template/haproxy.hcl /etc/consul_template.d/haproxy.hcl
cp $CONFIGDIR/consul_template/templates/haproxy.ctmpl /opt/consul_template/haproxy.ctmpl

# Upstart config
cp $SCRIPTSDIR/upstart/haproxy.conf /etc/init/haproxy.conf
