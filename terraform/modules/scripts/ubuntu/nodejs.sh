#!/bin/bash
set -e

NAME="${node_name}-$(hostname)"
SANITIZEDNAME=$${NAME//-/_}
SSLCERTDIR=/usr/local/etc
SSLSITECERTPATH=$SSLCERTDIR/site.crt
SSLVAULTCERTPATH=$SSLCERTDIR/vault.crt
GENERICPOLICYNAME=${vault_policy}
GENERICPOLICY=/opt/vault/policies/$GENERICPOLICYNAME.json
GENERICSECRETPATH=secret/$GENERICPOLICYNAME/$SANITIZEDNAME # Replace hyphens with underscores, Consul Template doesn't like hyphens
GENERICSECRETKEY=secret_key
GENERICSECRET="This is a secret stored in Vault for $NAME using the $GENERICPOLICYNAME policy"
AWSPOLICYNAME=${vault_policy}
AWSROLEPOLICY=/opt/vault/policies/aws_$AWSPOLICYNAME.json
AWSROLEPATH=aws/roles/$AWSPOLICYNAME
AWSCREDPATH=aws/creds/$AWSPOLICYNAME
VAULT=https://vault.service.consul:8200
CONSUL=http://127.0.0.1:8500
LOGS=/var/log/user_data.log

logger() {
  echo $1 | sudo tee -a $LOGS > /dev/null
}

preparepolicy() {
  FILEPATH=$1
  PARAMETER=$2

  sed -i -- 's/\"/\\"/g' $FILEPATH
  sed -i '1s/^/{"{{ parameter }}": "/' $FILEPATH
  sed -i '$s|$|"}|' $FILEPATH
  sed -i -- "s/{{ parameter }}/$PARAMETER/g" $FILEPATH
}

logger "Configuring Consul..."

sed -i -- "s/{{ atlas_username }}/${atlas_username}/g" /etc/consul.d/base.json
sed -i -- "s/{{ atlas_environment }}/${atlas_environment}/g" /etc/consul.d/base.json
sed -i -- "s/{{ atlas_token }}/${atlas_token}/g" /etc/consul.d/base.json
sed -i -- "s/{{ datacenter }}/${atlas_environment}/g" /etc/consul.d/base.json
sed -i -- "s/{{ node_name }}/$NAME/g" /etc/consul.d/base.json

service consul restart

if [[ "x${vault_token}" == "x" || "${vault_token}" == "REPLACE_IN_ATLAS" ]]; then
  logger "Exiting without setting Vault policy due to no Vault token."
  sed -i -- "s/retry = \"5s\"/retry = \"24h\"/g" /etc/consul_template.d/base.hcl

  exit 1
fi

logger "Updating certs..."

mkdir -p $SSLCERTDIR
chmod -R 0600 $SSLCERTDIR

echo "${site_ssl_cert}" | sudo tee $SSLSITECERTPATH > /dev/null
echo "${vault_ssl_cert}" | sudo tee $SSLVAULTCERTPATH > /dev/null

cp $SSLSITECERTPATH /usr/local/share/ca-certificates/.
cp $SSLVAULTCERTPATH /usr/local/share/ca-certificates/.
update-ca-certificates

logger "Waiting for Vault to become ready..."

SLEEPTIME=1
cget() { curl -sf "$VAULT/v1/sys/health?standbyok"; }

while ! cget | grep "\"initialized\":true,\"sealed\":false"; do
  if [ $SLEEPTIME -gt 24 ]; then
    logger "ERROR: VAULT SETUP NOT COMPLETE! Manual intervention required."
    exit 2
  else
    logger "Blocking until Vault is ready, waiting $SLEEPTIME second(s)..."
    sleep $SLEEPTIME
    SLEEPTIME=$((SLEEPTIME + 1))
  fi
done

logger "--- Generic Secret Backend Setup ---"
logger "Preparing Vault $NAME policy..."

preparepolicy $GENERICPOLICY rules

logger "Generating Vault $NAME policy..."

logger $(
  curl \
    -H "X-Vault-Token: ${vault_token}" \
    -H "Content-Type: application/json" \
    -LX PUT \
    -d @$GENERICPOLICY \
    $VAULT/v1/sys/policy/$GENERICPOLICYNAME
)

logger "Generating Vault $GENERICPOLICYNAME token..."

(cat <<TOKEN
{
  "display_name": "$GENERICPOLICYNAME",
  "ttl": "5s",
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

logger "Writing $NAME secret..."

logger $(
  curl \
    -H "X-Vault-Token: ${vault_token}" \
    -H "Content-Type: application/json" \
    -LX POST \
    -d "{\"$GENERICSECRETKEY\":\"$GENERICSECRET\"}" \
    $VAULT/v1/$GENERICSECRETPATH
)

logger "Update /opt/consul_template/vault_generic.ctmpl"

GENERICSECRETPATH=$${GENERICSECRETPATH//\//\\/}

sed -i -- "s/{{ node_name }}/$NAME/g" /opt/consul_template/vault_generic.ctmpl
sed -i -- "s/{{ secret_path }}/$GENERICSECRETPATH/g" /opt/consul_template/vault_generic.ctmpl
sed -i -- "s/{{ secret_key }}/$GENERICSECRETKEY/g" /opt/consul_template/vault_generic.ctmpl

logger "--- Transit Backend Setup ---"
logger "Checking if Transit backend is mounted..."

TRANSITMOUNTED=$(
  curl \
    -H "X-Vault-Token: ${vault_token}" \
    $VAULT/v1/sys/mounts \
    | grep -c transit
)

if [ $TRANSITMOUNTED -eq 0 ]; then
  logger "Mounting Transit backend..."

  logger $(
    curl \
      -H "X-Vault-Token: ${vault_token}" \
      -H "Content-Type: application/json" \
      -LX POST \
      -d "{\"type\":\"transit\", \"description\":\"encryption as a service\"}" \
      $VAULT/v1/sys/mounts/transit
  )

  logger "Transit backend mounted..."
else
  logger "Transit backend already mounted."
fi

logger "--- AWS Backend Setup ---"
logger "Checking if AWS backend is mounted..."

AWSMOUNTED=$(
  curl \
    -H "X-Vault-Token: ${vault_token}" \
    $VAULT/v1/sys/mounts \
    | grep -c aws
)

if [ $AWSMOUNTED -eq 0 ]; then
  logger "Mounting AWS backend..."

  logger $(
    curl \
      -H "X-Vault-Token: ${vault_token}" \
      -H "Content-Type: application/json" \
      -LX POST \
      -d "{\"type\":\"aws\", \"description\":\"dynamic aws iam credentials\"}" \
      $VAULT/v1/sys/mounts/aws
  )

  logger "AWS backend mounted..."
else
  logger "AWS backend already mounted."
fi

logger "Writing root IAM credentials..."

logger $(
  curl \
  -H "X-Vault-Token: ${vault_token}" \
  -H "Content-Type: application/json" \
  -LX POST \
  -d "{\"access_key\":\"${aws_access_id}\", \"secret_key\":\"${aws_secret_key}\", \"region\":\"${aws_region}\"}" \
  $VAULT/v1/aws/config/root
)

logger "Writing lease settings for generated credentials..."

logger $(
  curl \
  -H "X-Vault-Token: ${vault_token}" \
  -H "Content-Type: application/json" \
  -LX POST \
  -d "{\"lease\":\"5s\", \"lease_max\":\"10s\"}" \
  $VAULT/v1/aws/config/lease
)

logger "Preparing Vault AWS $NAME policy..."

preparepolicy $AWSROLEPOLICY policy

logger "Generating Vault AWS $NAME role..."

logger $(
  curl \
    -H "X-Vault-Token: ${vault_token}" \
    -H "Content-Type: application/json" \
    -LX PUT \
    -d @$AWSROLEPOLICY \
    $VAULT/v1/$AWSROLEPATH
)

logger "Update /opt/consul_template/vault_aws.ctmpl"

AWSCREDPATH=$${AWSCREDPATH//\//\\/}

sed -i -- "s/{{ node_name }}/$NAME/g" /opt/consul_template/vault_aws.ctmpl
sed -i -- "s/{{ cred_path }}/$AWSCREDPATH/g" /opt/consul_template/vault_aws.ctmpl

logger "--- Consul Template Configuration ---"
logger "Update Node.js Consul Template config"

SSLVAULTCERTPATH=$${SSLVAULTCERTPATH//\//\\/}

sed -i -- "s/{{ vault_token }}/$TOKEN/g" /etc/consul_template.d/nodejs.hcl
sed -i -- "s/{{ cert_path }}/$SSLVAULTCERTPATH/g" /etc/consul_template.d/nodejs.hcl

service consul_template restart

logger "Node.js configuration complete"

exit 0
