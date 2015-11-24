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
  source = "/opt/consul_template/vault_generic.ctmpl"
  destination = "/application/generic.html"
  command = "service nodejs restart"
}

template {
  source = "/opt/consul_template/vault_aws.ctmpl"
  destination = "/application/aws.html"
  command = "service nodejs restart"
}
