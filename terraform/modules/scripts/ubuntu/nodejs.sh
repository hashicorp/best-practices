#!/bin/bash
set -e

preparepolicy() {
FILEPATH=$1
sed -i -- 's/\"/\\"/g' $FILEPATH
sed -i '1s/^/{"rules": "{\n/' $FILEPATH
sed -i '$a}"}' $FILEPATH
}

NAME="${node_name}-$(hostname)"
SSLCERTDIR=/usr/local/etc
SSLSITECERTPATH=$SSLCERTDIR/site.crt
SSLVAULTCERTPATH=$SSLCERTDIR/vault.crt
POLICYNAME=nodejs
POLICY=/opt/vault/policies/$POLICYNAME.json
SECRETPATH=secret/$POLICYNAME/$${NAME//-/_} # Replace hyphens with underscores, Consul Template doesn't like hyphens
SECRETKEY=secret_key
SECRET="This is a secret stored in Vault for $NAME using the $POLICYNAME policy"
VAULT=https://vault.service.consul:8200
CONSUL=http://127.0.0.1:8500
LOGS=/var/log/user_data.log

echo "Configuring Consul..." | sudo tee -a $LOGS > /dev/null

sed -i -- "s/{{ atlas_username }}/${atlas_username}/g" /etc/consul.d/base.json
sed -i -- "s/{{ atlas_environment }}/${atlas_environment}/g" /etc/consul.d/base.json
sed -i -- "s/{{ atlas_token }}/${atlas_token}/g" /etc/consul.d/base.json
sed -i -- "s/{{ datacenter }}/${atlas_environment}/g" /etc/consul.d/base.json
sed -i -- "s/{{ node_name }}/$NAME/g" /etc/consul.d/base.json

service consul restart

if [[ "x${vault_token}" == "x" || "${vault_token}" == "REPLACE_IN_ATLAS" ]]; then
  echo "Exiting without setting Vault policy due to no Vault token" | sudo tee -a $LOGS > /dev/null
  sed -i -- "s/retry = \"5s\"/retry = \"5m\"/g" /etc/consul_template.d/base.hcl

  exit 1
fi

echo "Updating certs..." | sudo tee -a $LOGS > /dev/null

mkdir -p $SSLCERTDIR
chmod -R 0600 $SSLCERTDIR

echo "${site_ssl_cert}" | sudo tee $SSLSITECERTPATH > /dev/null
echo "${vault_ssl_cert}" | sudo tee $SSLVAULTCERTPATH > /dev/null

cp $SSLSITECERTPATH /usr/local/share/ca-certificates/.
cp $SSLVAULTCERTPATH /usr/local/share/ca-certificates/.
update-ca-certificates

echo "Waiting for Vault to become ready..." | sudo tee -a $LOGS > /dev/null

SLEEPTIME=1
cget() { curl -sf "$VAULT/v1/sys/health?standbyok"; }

while ! cget | grep "\"initialized\":true,\"sealed\":false"; do
  if [ $SLEEPTIME -gt 24 ]; then
    echo "ERROR: VAULT SETUP NOT COMPLETE! Manual intervention required." | sudo tee -a $LOGS > /dev/null
    exit 2
  else
    echo "Blocking until Vault is ready, waiting $SLEEPTIME second(s)..." | sudo tee -a $LOGS > /dev/null
    sleep $SLEEPTIME
    SLEEPTIME=$((SLEEPTIME + 1))
  fi
done

echo "Generating Vault $NAME policy..." | sudo tee -a $LOGS > /dev/null

preparepolicy $POLICY

curl \
  -H "X-Vault-Token: ${vault_token}" \
  -H "Content-Type: application/json" \
  -LX PUT \
  -d @$POLICY \
  $VAULT/v1/sys/policy/$POLICYNAME

echo "Generating Vault $POLICYNAME token..." | sudo tee -a $LOGS > /dev/null

(cat <<TOKEN
{
  "display_name": "$POLICYNAME",
  "ttl": "1h",
  "no_parent": "true",
  "policies": [
    "$POLICYNAME"
  ]
}
TOKEN
) > /tmp/$POLICYNAME-token.json

TOKEN=$(
curl \
  -H "X-Vault-Token: ${vault_token}" \
  -H "Content-Type: application/json" \
  -LX POST \
  -d @/tmp/$POLICYNAME-token.json \
  $VAULT/v1/auth/token/create \
  | grep -Po '"client_token":.*?[^\\]",' | awk -F\" '{print $4}'
)

rm -rf /tmp/$POLICYNAME-token.json

echo "Writing $NAME secret..." | sudo tee -a $LOGS > /dev/null

curl \
  -H "X-Vault-Token: ${vault_token}" \
  -H "Content-Type: application/json" \
  -LX POST \
  -d "{\"$SECRETKEY\":\"$SECRET\"}" \
  $VAULT/v1/$SECRETPATH

echo "Update Node.js Consul Template config" | sudo tee -a $LOGS > /dev/null

SSLVAULTCERTPATH=$${SSLVAULTCERTPATH//\//\\/}

sed -i -- "s/{{ vault_token }}/$TOKEN/g" /etc/consul_template.d/nodejs.hcl
sed -i -- "s/{{ cert_path }}/$SSLVAULTCERTPATH/g" /etc/consul_template.d/nodejs.hcl

SECRETPATH=$${SECRETPATH//\//\\/}

sed -i -- "s/{{ node_name }}/$NAME/g" /opt/consul_template/nodejs.ctmpl
sed -i -- "s/{{ secret_path }}/$SECRETPATH/g" /opt/consul_template/nodejs.ctmpl
sed -i -- "s/{{ secret_key }}/$SECRETKEY/g" /opt/consul_template/nodejs.ctmpl

service consul_template restart

echo "Node.js configuration complete" | sudo tee -a $LOGS > /dev/null

exit 0
