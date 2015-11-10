#!/bin/bash
set -e

usage() {
  cat <<EOF
Generate a self-signed SSL cert

Prerequisites:

Requires openssl is installed and available on \$PATH.

Usage:

  $0 <DOMAIN> <TYPE> <COMPANY>

Where DOMAIN is the domain to be deployed, TYPE is the type of cert this is, and COMPANY is your companies name.

This will generate a single self-signed cert with the following subjectAltNames in the directory specified.

 * DOMAIN
 * vault.DOMAIN
 * vpn.DOMAIN
 * nodejs.DOMAIN
 * haproxy.DOMAIN
 * private.haproxy.DOMAIN
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

TYPE=$2

if [ "x$TYPE" == "x" ]; then
  echo
  echo "ERROR: Specify type as the second argument, e.g. demo"
  echo
  usage
fi

COMPANY=$3

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

CERTPATH=certs
BASE="${CERTPATH}/${TYPE}"
CSR="${BASE}.csr"
KEY="${BASE}.key"
CRT="${BASE}.crt"
SSLCONF=${BUILDDIR}/selfsigned_openssl.cnf
mkdir -p $CERTPATH

if [ "$TYPE" == "consul" ]; then
  echo "Creating Consul cert"

  cp openssl.cnf ${SSLCONF}
  (cat <<EOF
[ alt_names ]
DNS.1 = vault.service.${DOMAIN}
DNS.2 = consul.service.${DOMAIN}
DNS.3 = *.node.${DOMAIN}
IP.1 = 0.0.0.0
IP.2 = 127.0.0.1
EOF
) >> $SSLCONF

  SUBJ="/C=US/ST=California/L=San Francisco/O=${COMPANY}/OU=${TYPE}/CN=*.node.${DOMAIN}"
else
  echo "Creating site cert for ${TYPE}"

  cp openssl.cnf ${SSLCONF}
  (cat <<EOF
[ alt_names ]
DNS.1 = ${DOMAIN}
DNS.2 = vault.${DOMAIN}
DNS.3 = vpn.${DOMAIN}
DNS.4 = nodejs.${DOMAIN}
DNS.5 = haproxy.${DOMAIN}
DNS.6 = private.haproxy.${DOMAIN}
EOF
) >> $SSLCONF

  SUBJ="/C=US/ST=California/L=San Francisco/O=${COMPANY}/OU=${TYPE}/CN=${DOMAIN}"
fi

openssl genrsa -out $KEY 2048
openssl req -new -out $CSR -key $KEY -subj "${SUBJ}" -config $SSLCONF
openssl x509 -req -days 3650 -in $CSR -signkey $KEY -out $CRT -extensions v3_req -extfile $SSLCONF
