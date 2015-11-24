#!/bin/bash
set -e

usage() {
  cat <<EOF
Generate a self-signed SSL cert

Prerequisites:

Requires openssl is installed and available on \$PATH.

Usage:

  $0 <DOMAIN> <COMPANY>

Where DOMAIN is the domain to be deployed and COMPANY is your companies name.

This will generate a self-signed site cert with the following subjectAltNames in the directory specified.

 * DOMAIN
 * vault.DOMAIN
 * vpn.DOMAIN
 * nodejs.DOMAIN
 * haproxy.DOMAIN
 * private.haproxy.DOMAIN

And a self-signed cert for Consul/Vault with the following subjectAltNames in the directory specified.

 * DOMAIN
 * *.node.consul
 * *.service.consul

 * IP
 * 0.0.0.0
 * 127.0.0.1
EOF

  exit 1
}

if ! which openssl > /dev/null; then
  echo
  echo "ERROR: The openssl executable was not found. This script requires openssl."
  echo
  usage
fi

DOMAIN=$1

if [ "x$DOMAIN" == "x" ]; then
  echo
  echo "ERROR: Specify base domain as the first argument, e.g. mycompany.com"
  echo
  usage
fi

COMPANY=$2

if [ "x$COMPANY" == "x" ]; then
  echo
  echo "ERROR: Specify company as the third argument, e.g. HashiCorp"
  echo
  usage
fi

# Create a temporary build dir and make sure we clean it up. For
# debugging, comment out the trap line.
BUILDDIR=`mktemp -d /tmp/ssl-XXXXXX`
trap "rm -rf $BUILDDIR" INT TERM EXIT

echo "Creating site cert"

OS=$(uname -s)
BASE="site"
CSR="${BASE}.csr"
KEY="${BASE}.key"
CRT="${BASE}.crt"
SITESSLCONF=${BUILDDIR}/site_selfsigned_openssl.cnf

cp openssl.cnf ${SITESSLCONF}
(cat <<EOF
[ alt_names ]
DNS.1 = ${DOMAIN}
DNS.2 = vault.${DOMAIN}
DNS.3 = vpn.${DOMAIN}
DNS.4 = nodejs.${DOMAIN}
DNS.5 = haproxy.${DOMAIN}
DNS.6 = private.haproxy.${DOMAIN}
EOF
) >> $SITESSLCONF

# MinGW/MSYS issue: http://stackoverflow.com/questions/31506158/running-openssl-from-a-bash-script-on-windows-subject-does-not-start-with
if [[ "${OS}" == "MINGW32"* || "${OS}" == "MINGW64"* || "${OS}" == "MSYS"* ]]; then
  SUBJ="//C=US\ST=California\L=San Francisco\O=${COMPANY}\OU=${BASE}\CN=${DOMAIN}"
else
  SUBJ="/C=US/ST=California/L=San Francisco/O=${COMPANY}/OU=${BASE}/CN=${DOMAIN}"
fi

openssl genrsa -out $KEY 2048
openssl req -new -out $CSR -key $KEY -subj "${SUBJ}" -config $SITESSLCONF
openssl x509 -req -days 3650 -in $CSR -signkey $KEY -out $CRT -extensions v3_req -extfile $SITESSLCONF

echo "Creating Vault cert"

DOMAIN=consul
BASE="vault"
CSR="${BASE}.csr"
KEY="${BASE}.key"
CRT="${BASE}.crt"
VAULTSSLCONF=${BUILDDIR}/vault_selfsigned_openssl.cnf

 cp openssl.cnf ${VAULTSSLCONF}
 (cat <<EOF
[ alt_names ]
DNS.1 = *.node.${DOMAIN}
DNS.2 = *.service.${DOMAIN}
IP.1 = 0.0.0.0
IP.2 = 127.0.0.1
EOF
) >> $VAULTSSLCONF

# MinGW/MSYS issue: http://stackoverflow.com/questions/31506158/running-openssl-from-a-bash-script-on-windows-subject-does-not-start-with
if [[ "${OS}" == "MINGW32"* || "${OS}" == "MINGW64"* || "${OS}" == "MSYS"* ]]; then
  SUBJ="//C=US\ST=California\L=San Francisco\O=${COMPANY}\OU=${BASE}\CN=*.${DOMAIN}"
else
  SUBJ="/C=US/ST=California/L=San Francisco/O=${COMPANY}/OU=${BASE}/CN=*.${DOMAIN}"
fi

openssl genrsa -out $KEY 2048
openssl req -new -out $CSR -key $KEY -subj "${SUBJ}" -config $VAULTSSLCONF
openssl x509 -req -days 3650 -in $CSR -signkey $KEY -out $CRT -extensions v3_req -extfile $VAULTSSLCONF
