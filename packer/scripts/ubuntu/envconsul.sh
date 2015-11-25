#!/bin/bash
set -e

cd /tmp

CONFIGDIR=/ops/$1
ECDOWNLOAD=https://github.com/hashicorp/envconsul/releases/download/v0.6.0/envconsul_0.6.0_linux_amd64.zip
ECCONFIGDIR=/etc/envconsul.d

echo Fetching envconsul...
curl -L $ECDOWNLOAD > envconsul.zip

echo Installing envconsul...
unzip envconsul.zip -d /usr/local/bin
chmod 0755 /usr/local/bin/envconsul
chown root:root /usr/local/bin/envconsul

echo Configuring Consul Template...
mkdir -p $ECCONFIGDIR
chmod 755 $ECCONFIGDIR

# envconsul config
cp $CONFIGDIR/envconsul/base.hcl $ECCONFIGDIR/base.hcl
