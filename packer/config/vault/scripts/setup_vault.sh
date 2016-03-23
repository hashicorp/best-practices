#!/bin/bash
set -e

cr=`echo '\n.'`
cr=${cr%.}
read -p "Running this script will initialize & unseal Vault,${cr}then put your unseal keys and root token into Consul KV.${cr}${cr}If you're sure you want to continue, type 'yes': `echo '\n> '`" ANSWER

if [ "$ANSWER" != "yes" ]; then
  echo
  echo "Exiting without intializing & unsealing Vault, no keys or tokens were stored."
  echo
  exit 1
fi

cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }

if [ ! $(cget root-token) ]; then
  echo "Initialize Vault"
  vault init | tee /tmp/vault.init > /dev/null

  # Store master keys in consul for operator to retrieve and remove
  COUNTER=1
  cat /tmp/vault.init | grep '^Key' | awk '{print $3}' | for key in $(cat -); do
    curl -fX PUT 127.0.0.1:8500/v1/kv/service/vault/unseal-key-$COUNTER -d $key
    COUNTER=$((COUNTER + 1))
  done

  export ROOT_TOKEN=$(cat /tmp/vault.init | grep '^Initial' | awk '{print $4}')
  curl -fX PUT 127.0.0.1:8500/v1/kv/service/vault/root-token -d $ROOT_TOKEN

  echo "Remove master keys from disk"
  shred /tmp/vault.init

  echo "Setup Vault demo"
  curl -fX PUT 127.0.0.1:8500/v1/kv/service/nodejs/show_vault -d "true"
  curl -fX PUT 127.0.0.1:8500/v1/kv/service/nodejs/vault_files -d "aws.html,generic.html"
else
  echo "Vault has already been initialized, skipping."
fi

echo "Unsealing Vault"
vault unseal $(cget unseal-key-1)
vault unseal $(cget unseal-key-2)
vault unseal $(cget unseal-key-3)

echo "Vault setup complete."

instructions() {
  cat <<EOF
We use an instance of HashiCorp Vault for secrets management.

It has been automatically initialized and unsealed once. Future unsealing must
be done manually.

The unseal keys and root token have been temporarily stored in Consul K/V.

  /service/vault/root-token
  /service/vault/unseal-key-{1..5}

Please securely distribute and record these secrets and remove them from Consul.
EOF

  exit 1
}

instructions
