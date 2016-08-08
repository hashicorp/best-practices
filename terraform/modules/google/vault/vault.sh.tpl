#!/bin/bash
set -e

SSLDIR=/usr/local/etc
SSLCERTPATH=$SSLDIR/vault.crt
SSLKEYPATH=$SSLDIR/vault.key

echo "Configuring Consul..."

sed -i -- "s/{{ atlas_username }}/${atlas_username}/g" /etc/consul.d/base.json
sed -i -- "s/{{ atlas_environment }}/${atlas_environment}/g" /etc/consul.d/base.json
sed -i -- "s/{{ atlas_token }}/${atlas_token}/g" /etc/consul.d/base.json
sed -i -- "s/{{ datacenter }}/${atlas_environment}/g" /etc/consul.d/base.json
sed -i -- "s/{{ node_name }}/${node_name}/g" /etc/consul.d/base.json
sed -i -- "s/{{ node_name }}/${node_name}/g" /etc/consul.d/vault.json

service consul restart

echo "Updating cert..."

mkdir -p $SSLDIR
chmod -R 0600 $SSLDIR

echo "${ssl_cert}" | sudo tee $SSLCERTPATH > /dev/null
echo "${ssl_key}" | sudo tee $SSLKEYPATH > /dev/null

cp "$SSLCERTPATH" /usr/local/share/ca-certificates/.
update-ca-certificates

echo "Configuring Vault..."

SSLCERTPATH=$${SSLCERTPATH//\//\\/}
SSLKEYPATH=$${SSLKEYPATH//\//\\/}

sed -i -- "s/{{ node_name }}/${node_name}/g" /etc/vault.d/vault.hcl
sed -i -- "s/{{ tls_cert_file }}/$SSLCERTPATH/g" /etc/vault.d/vault.hcl
sed -i -- "s/{{ tls_key_file }}/$SSLKEYPATH/g" /etc/vault.d/vault.hcl

service vault restart

exit 0
