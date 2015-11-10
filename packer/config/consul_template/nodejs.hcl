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

template {
  source = "/opt/consul_template/nodejs.ctmpl"
  destination = "/application/index.html"
  command = "service nodejs restart"
}
