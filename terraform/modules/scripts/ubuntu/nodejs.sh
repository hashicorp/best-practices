#!/bin/bash
set -e

preparepolicy() {
FILEPATH=$1
PARAMETER=$2

sed -i -- 's/\"/\\"/g' $FILEPATH
sed -i '1s/^/{"{{ parameter }}": "/' $FILEPATH
sed -i '$s|$|"}|' $FILEPATH
sed -i -- "s/{{ parameter }}/$PARAMETER/g" $FILEPATH
}

NAME="${node_name}-$(hostname)"
SANITIZEDNAME=$${NAME//-/_}
SSLCERTDIR=/usr/local/etc
SSLSITECERTPATH=$SSLCERTDIR/site.crt
SSLVAULTCERTPATH=$SSLCERTDIR/vault.crt
GENERICPOLICYNAME=${policy_name}
GENERICPOLICY=/opt/vault/policies/$GENERICPOLICYNAME.json
GENERICSECRETPATH=secret/$GENERICPOLICYNAME/$SANITIZEDNAME # Replace hyphens with underscores, Consul Template doesn't like hyphens
GENERICSECRETKEY=secret_key
GENERICSECRET="This is a secret stored in Vault for $NAME using the $GENERICPOLICYNAME policy"
AWSPOLICYNAME=${policy_name}
AWSROLEPOLICY=/opt/vault/policies/aws_$AWSPOLICYNAME.json
AWSROLEPATH=aws/roles/$AWSPOLICYNAME
AWSCREDPATH=aws/creds/$AWSPOLICYNAME
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

preparepolicy $GENERICPOLICY rules

curl \
  -H "X-Vault-Token: ${vault_token}" \
  -H "Content-Type: application/json" \
  -LX PUT \
  -d @$GENERICPOLICY \
  $VAULT/v1/sys/policy/$GENERICPOLICYNAME

echo "Generating Vault $GENERICPOLICYNAME token..." | sudo tee -a $LOGS > /dev/null

(cat <<TOKEN
{
  "display_name": "$GENERICPOLICYNAME",
  "ttl": "1h",
  "no_parent": "true",
  "policies": [
    "$GENERICPOLICYNAME"
  ]
}
TOKEN
) > /tmp/$GENERICPOLICYNAME-token.json

TOKEN=$(
curl \
  -H "X-Vault-Token: ${vault_token}" \
  -H "Content-Type: application/json" \
  -LX POST \
  -d @/tmp/$GENERICPOLICYNAME-token.json \
  $VAULT/v1/auth/token/create \
  | grep -Po '"client_token":.*?[^\\]",' | awk -F\" '{print $4}'
)

rm -rf /tmp/$GENERICPOLICYNAME-token.json

echo "Writing $NAME secret..." | sudo tee -a $LOGS > /dev/null

curl \
  -H "X-Vault-Token: ${vault_token}" \
  -H "Content-Type: application/json" \
  -LX POST \
  -d "{\"$GENERICSECRETKEY\":\"$GENERICSECRET\"}" \
  $VAULT/v1/$GENERICSECRETPATH

echo "Generating Vault AWS $NAME role..." | sudo tee -a $LOGS > /dev/null

preparepolicy $AWSROLEPOLICY policy

curl \
  -H "X-Vault-Token: ${vault_token}" \
  -H "Content-Type: application/json" \
  -LX PUT \
  -d @$AWSROLEPOLICY \
  $VAULT/v1/$AWSROLEPATH

echo "Update Node.js Consul Template config" | sudo tee -a $LOGS > /dev/null

SSLVAULTCERTPATH=$${SSLVAULTCERTPATH//\//\\/}

sed -i -- "s/{{ vault_token }}/$TOKEN/g" /etc/consul_template.d/nodejs.hcl
sed -i -- "s/{{ cert_path }}/$SSLVAULTCERTPATH/g" /etc/consul_template.d/nodejs.hcl

GENERICSECRETPATH=$${GENERICSECRETPATH//\//\\/}
AWSCREDPATH=$${AWSCREDPATH//\//\\/}

sed -i -- "s/{{ node_name }}/$NAME/g" /opt/consul_template/nodejs.ctmpl
sed -i -- "s/{{ secret_path }}/$GENERICSECRETPATH/g" /opt/consul_template/nodejs.ctmpl
sed -i -- "s/{{ secret_key }}/$GENERICSECRETKEY/g" /opt/consul_template/nodejs.ctmpl
sed -i -- "s/{{ cred_path }}/$AWSCREDPATH/g" /opt/consul_template/nodejs.ctmpl

service consul_template restart

echo "Node.js configuration complete" | sudo tee -a $LOGS > /dev/null

exit 0
