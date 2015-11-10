#!/bin/bash
set -e

NODENAME="${node_name}-$(hostname)"

echo "Configuring Consul..."

sed -i -- "s/{{ atlas_username }}/${atlas_username}/g" /etc/consul.d/base.json
sed -i -- "s/{{ atlas_environment }}/${atlas_environment}/g" /etc/consul.d/base.json
sed -i -- "s/{{ atlas_token }}/${atlas_token}/g" /etc/consul.d/base.json
sed -i -- "s/{{ datacenter }}/${atlas_environment}/g" /etc/consul.d/base.json
sed -i -- "s/{{ node_name }}/$NODENAME/g" /etc/consul.d/base.json

service consul restart

echo "Configuring RabbitMQ..."

sleep 20
sudo rabbitmqctl add_user '${username}' '${password}'
sudo rabbitmqctl add_vhost ${vhost}
sudo rabbitmqctl set_permissions -p '${vhost}' '${username}' '.*' '.*' '.*'
sudo rabbitmqctl set_user_tags '${username}' administrator

service rabbitmq-server restart

exit 0
