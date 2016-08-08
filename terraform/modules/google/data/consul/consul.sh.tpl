#!/bin/bash
set -e

echo "Configuring Consul..."

sed -i -- "s/{{ atlas_username }}/${atlas_username}/g" /etc/consul.d/base.json
sed -i -- "s/{{ atlas_environment }}/${atlas_environment}/g" /etc/consul.d/base.json
sed -i -- "s/{{ atlas_token }}/${atlas_token}/g" /etc/consul.d/base.json
sed -i -- "s/{{ consul_server_count }}/${consul_server_count}/g" /etc/consul.d/base.json
sed -i -- "s/{{ datacenter }}/${atlas_environment}/g" /etc/consul.d/base.json
sed -i -- "s/{{ node_name }}/${node_name}/g" /etc/consul.d/base.json

service consul restart

exit 0
