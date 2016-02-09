#!/bin/bash

NAME="${node_name}-$(hostname)"
SANITIZEDNAME=$${NAME//-/_} # Replace hyphens with underscores, Consul Template doesn't like hyphens
SSLCERTDIR=/usr/local/etc
SSLSITECERTPATH=$SSLCERTDIR/site.crt
SSLVAULTCERTPATH=$SSLCERTDIR/vault.crt
NODEJSPOLICYNAME=${vault_policy}
NODEJSPOLICY=/opt/vault/policies/$NODEJSPOLICYNAME.json
GENERICSECRETPATH=secret/$NODEJSPOLICYNAME/$SANITIZEDNAME
GENERICSECRETKEY=secret_key
GENERICSECRET="This is a secret stored in Vault for $NAME using the $NODEJSPOLICYNAME policy"
AWSROLEPOLICY=/opt/vault/policies/aws_$NODEJSPOLICYNAME.json
AWSROLEPATH=aws/roles/$NODEJSPOLICYNAME
AWSCREDPATH=aws/creds/$NODEJSPOLICYNAME
VAULT=https://vault.service.consul:8200
CONSUL=http://127.0.0.1:8500
LOGS=/var/log/user_data.log

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT nodejs.sh: $1" | sudo tee -a $LOGS > /dev/null
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
sed -i -- "s/{{ deploy }}/${deploy}/g" /etc/consul.d/nodejs.json

service consul restart

logger "Updating certs..."

mkdir -p $SSLCERTDIR
chmod -R 0600 $SSLCERTDIR

echo "${site_ssl_cert}" | sudo tee $SSLSITECERTPATH > /dev/null
echo "${vault_ssl_cert}" | sudo tee $SSLVAULTCERTPATH > /dev/null

cp $SSLSITECERTPATH /usr/local/share/ca-certificates/.
cp $SSLVAULTCERTPATH /usr/local/share/ca-certificates/.
update-ca-certificates

logger "Checking for Vault token..."

if [[ "x${vault_token}" == "x" || "${vault_token}" == "REPLACE_IN_ATLAS" ]]; then
  logger "Setting consul_template retry to 1h and stopping service."
  sed -i -- "s/retry     = \"5s\"/retry     = \"1h\"/g" /etc/consul_template.d/base.hcl
  service consul_template stop

  logger "Setting envconsul retry to 1h."
  sed -i -- "s/retry       = \"5s\"/retry       = \"1h\"/g" /etc/envconsul.d/base.hcl
  service nodejs restart

  logger "Exiting without setting Vault policy due to no Vault token."

  exit 1
fi

logger "Waiting for Vault to become ready..."

SLEEPTIME=1
cget() { curl -sf "$VAULT/v1/sys/health?standbyok"; }

while ! cget | grep "\"initialized\":true,\"sealed\":false"; do
  if [ $SLEEPTIME -gt 15 ]; then
    logger "ERROR: VAULT SETUP NOT COMPLETE! Manual intervention required."
    exit 2
  else
    logger "Blocking until Vault is ready, waiting $SLEEPTIME second(s)..."
    sleep $SLEEPTIME
    SLEEPTIME=$((SLEEPTIME + 1))
  fi
done

logger "--- Vault Policy Setup ---"
logger "Preparing Vault $NODEJSPOLICYNAME policy..."

preparepolicy $NODEJSPOLICY rules

logger "Generating Vault $NODEJSPOLICYNAME policy..."

logger $(
  curl \
    -H "X-Vault-Token: ${vault_token}" \
    -H "Content-Type: application/json" \
    -LX PUT \
    -d @$NODEJSPOLICY \
    $VAULT/v1/sys/policy/$NODEJSPOLICYNAME
)

logger "Generating Vault $NODEJSPOLICYNAME token..."

(cat <<TOKEN
{
  "display_name": "$NODEJSPOLICYNAME",
  "ttl": "1m",
  "no_parent": "true",
  "policies": [
    "$NODEJSPOLICYNAME"
  ]
}
TOKEN
) > /tmp/$NODEJSPOLICYNAME-token.json

TOKEN=$(
  curl \
    -H "X-Vault-Token: ${vault_token}" \
    -H "Content-Type: application/json" \
    -LX POST \
    -d @/tmp/$NODEJSPOLICYNAME-token.json \
    $VAULT/v1/auth/token/create \
    | grep -Po '"client_token":.*?[^\\]",' | awk -F\" '{print $4}'
)

rm -rf /tmp/$NODEJSPOLICYNAME-token.json

SSLVAULTCERTPATH=$${SSLVAULTCERTPATH//\//\\/}

logger "Update /etc/consul_template.d/nodejs.hcl with vault_token and cert_path"

sed -i -- "s/{{ vault_token }}/$TOKEN/g" /etc/consul_template.d/nodejs.hcl
sed -i -- "s/{{ cert_path }}/$SSLVAULTCERTPATH/g" /etc/consul_template.d/nodejs.hcl

logger "Update /etc/envconsul.d/nodejs.hcl with vault_token and cert_path"

sed -i -- "s/{{ vault_token }}/$TOKEN/g" /etc/envconsul.d/nodejs.hcl
sed -i -- "s/{{ cert_path }}/$SSLVAULTCERTPATH/g" /etc/envconsul.d/nodejs.hcl

logger "--- Generic Secret Backend Setup ---"
logger "Writing $NAME secret..."

logger $(
  curl \
    -H "X-Vault-Token: ${vault_token}" \
    -H "Content-Type: application/json" \
    -LX POST \
    -d "{\"$GENERICSECRETKEY\": \"$GENERICSECRET\", \"ttl\": \"1m\"}" \
    $VAULT/v1/$GENERICSECRETPATH
)

GENERICSECRETPATH=$${GENERICSECRETPATH//\//\\/}

logger "Update /opt/consul_template/vault_generic.ctmpl"

sed -i -- "s/{{ node_name }}/$NAME/g" /opt/consul_template/vault_generic.ctmpl
sed -i -- "s/{{ secret_path }}/$GENERICSECRETPATH/g" /opt/consul_template/vault_generic.ctmpl
sed -i -- "s/{{ secret_key }}/$GENERICSECRETKEY/g" /opt/consul_template/vault_generic.ctmpl

logger "Update /etc/envconsul.d/nodejs.hcl with secret_path"

sed -i -- "s/{{ secret_path }}/$GENERICSECRETPATH/g" /etc/envconsul.d/nodejs.hcl

service nodejs restart

logger "--- Transit Backend Setup ---"
logger "Checking if Transit backend is mounted..."

TRANSITMOUNTED=$(
  curl \
    -H "X-Vault-Token: ${vault_token}" \
    -LX GET \
    $VAULT/v1/sys/mounts \
    | grep -c "transit"
)

echo "Transit backend mount status: $TRANSITMOUNTED"

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

  logger "Transit backend mounted."
else
  logger "Transit backend already mounted."
fi

logger "--- AWS Backend Setup ---"
logger "Checking if AWS backend is mounted..."

AWSMOUNTED=$(
  curl \
    -H "X-Vault-Token: ${vault_token}" \
    -LX GET \
    $VAULT/v1/sys/mounts \
    | grep -c "aws"
)

echo "AWS backend mount status: $AWSMOUNTED"

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

  logger "AWS backend mounted."
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
  -d "{\"lease\": \"1m\", \"lease_max\": \"2m\"}" \
  $VAULT/v1/aws/config/lease
)

logger "Preparing Vault AWS $NODEJSPOLICYNAME policy..."

preparepolicy $AWSROLEPOLICY policy

logger "Generating Vault AWS $NODEJSPOLICYNAME role..."

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

service consul_template restart

logger "Node.js configuration complete"

exit 0
