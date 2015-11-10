#!/bin/bash
set -e

# https://www.rabbitmq.com/install-debian.html
echo Installing RabbitMQ Server...
cat <<EOF > /etc/apt/sources.list.d/rabbitmq.list
deb http://www.rabbitmq.com/debian/ testing main
EOF

curl https://www.rabbitmq.com/rabbitmq-signing-key-public.asc -o /tmp/rabbitmq-signing-key-public.asc
apt-key add /tmp/rabbitmq-signing-key-public.asc
rm /tmp/rabbitmq-signing-key-public.asc

apt-get -y install rabbitmq-server
rabbitmq-plugins enable rabbitmq_management
service rabbitmq-server restart
