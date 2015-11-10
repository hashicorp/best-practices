#!/bin/bash
set -e

DNSLISTENADDR=$1

echo Installing Dnsmasq...

apt-get -y update
apt-get -y upgrade
apt-get -y install dnsmasq-base dnsmasq

echo Configuring Dnsmasq...

cat <<EOF >/etc/dnsmasq.d/consul
server=/consul/127.0.0.1#8600
listen-address=$DNSLISTENADDR
bind-interfaces
EOF

cat /etc/dnsmasq.d/consul
