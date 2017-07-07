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

create_cert() {
  local base="$1"
  local domain="$2"
  local company="$3"
  local sslconf="$4"

  echo "Creating $base cert"

  local os="$(uname -s)"
  local csr="${base}.csr"
  local key="${base}.key"
  local crt="${base}.crt"

  # MinGW/MSYS issue: http://stackoverflow.com/questions/31506158/running-openssl-from-a-bash-script-on-windows-subject-does-not-start-with
  local subj="/C=US/ST=California/L=San Francisco/O=${company}/OU=${base}/CN=${domain}"
  if [[ "${os}" == "MINGW32"* || "${os}" == "MINGW64"* || "${os}" == "MSYS"* ]]; then
    subj="//C=US\ST=California\L=San Francisco\O=${company}\OU=${base}\CN=${domain}"
  fi

  openssl genrsa -out "$key" 2048
  openssl req -new -out "$csr" -key "$key" -subj "${subj}" -config "$sslconf"
  openssl x509 -req -days 3650 -in "$csr" -signkey "$key" -out "$crt" -extensions v3_req -extfile "$sslconf"
}

main() {
  local domain="$1"
  local company="$2"

  if ! which openssl > /dev/null; then
    echo
    echo "ERROR: The openssl executable was not found. This script requires openssl."
    echo
    usage
  fi

  if [[ -z "$domain" ]]; then
    echo
    echo "ERROR: Specify base domain as the first argument, e.g. mycompany.com"
    echo
    usage
  fi

  if [[ -z "$company" ]]; then
    echo
    echo "ERROR: Specify company as the third argument, e.g. HashiCorp"
    echo
    usage
  fi

  umask 077

  # Create a temporary build dir and make sure we clean it up. For
  # debugging, comment out the trap line.
  local builddir="$(mktemp -d /tmp/ssl-XXXXXX)"
  trap "rm -rf '$builddir'" INT TERM EXIT

  local sslconf="${builddir}/site_selfsigned_openssl.cnf"
  cp openssl.cnf "${sslconf}"
  (cat <<EOF
  [ alt_names ]
  DNS.1 = ${domain}
  DNS.2 = vault.${domain}
  DNS.3 = vpn.${domain}
  DNS.4 = nodejs.${domain}
  DNS.5 = haproxy.${domain}
  DNS.6 = private.haproxy.${domain}
EOF
  ) >> "$sslconf"
  create_cert "site" "$domain" "$company" "$sslconf"

  domain="consul"
  sslconf=${builddir}/vault_selfsigned_openssl.cnf
  cp openssl.cnf "${sslconf}"
  (cat <<EOF
  [ alt_names ]
  DNS.1 = *.node.${domain}
  DNS.2 = *.service.${domain}
  IP.1 = 0.0.0.0
  IP.2 = 127.0.0.1
EOF
  ) >> "$sslconf"
  create_cert "vault" "$domain" "$company" "$sslconf"
}

main "$@"

