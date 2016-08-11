template {
  source = "/opt/consul_template/vault_aws.ctmpl"
  destination = "/application/vault/aws.html"
  command = "service nodejs restart"
}
