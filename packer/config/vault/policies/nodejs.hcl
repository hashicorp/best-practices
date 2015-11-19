# Allow renewal of leases for secrets
path "sys/renew/*" {
  policy = "write"
}

# Allow renewal of token leases
path "auth/token/renew/*" {
  policy = "write"
}

# Transit backend
path "transit/encrypt/nodejs_*" {
  policy = "write"
}

path "transit/decrypt/nodejs_*" {
  policy = "write"
}

# Secrets backend
path "secret/nodejs/*" {
  policy = "read"
}

# AWS backend
path "aws/creds/*" {
  policy = "read"
}
