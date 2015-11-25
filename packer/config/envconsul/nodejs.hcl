vault {
  address = "https://vault.service.consul:8200"
  token = "{{ vault_token }}"
  renew = true

  ssl {
    enabled = true
    verify = true
    ca_cert = "{{ cert_path }}"
  }
}

secret {
  path = "{{ secret_path }}"
}

prefix {
  path = "service/nodejs"
}
