#!/bin/bash
set -e

cd /tmp

ECVERSION=0.6.0
CONFIGDIR=/ops/$1
ECDOWNLOAD=https://releases.hashicorp.com/envconsul/${ECVERSION}/envconsul_${ECVERSION}_linux_amd64.zip
ECCONFIGDIR=/etc/envconsul.d

echo Fetching envconsul...
curl -L $ECDOWNLOAD > envconsul.zip

echo Installing envconsul...
unzip envconsul.zip -d /usr/local/bin
chmod 0755 /usr/local/bin/envconsul
chown root:root /usr/local/bin/envconsul

echo Configuring envconsul...
mkdir -p $ECCONFIGDIR
chmod 755 $ECCONFIGDIR

# envconsul config
cp $CONFIGDIR/envconsul/base.hcl $ECCONFIGDIR/base.hcl
