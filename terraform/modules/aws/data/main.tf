variable "name" {}
variable "region" {}
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "private_subnet_ids" {}
variable "public_subnet_ids" {}
variable "ssl_cert" {}
variable "ssl_key" {}
variable "key_name" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_token" {}
variable "domain" {}
variable "sub_domain" {}
variable "route_zone_id" {}

variable "consul_user_data" {}
variable "consul_instance_type" {}
variable "consul_ips" {}
variable "consul_amis" {}

variable "vault_user_data" {}
variable "vault_instance_type" {}
variable "vault_nodes" {}
variable "vault_amis" {}

module "consul" {
  source = "./consul"

  name               = "${var.name}-consul"
  vpc_id             = "${var.vpc_id}"
  vpc_cidr           = "${var.vpc_cidr}"
  private_subnet_ids = "${var.private_subnet_ids}"
  key_name           = "${var.key_name}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  user_data          = "${var.consul_user_data}"
  instance_type      = "${var.consul_instance_type}"
  static_ips         = "${var.consul_ips}"
  amis               = "${var.consul_amis}"
}

module "vault" {
  source = "./vault"

  name               = "${var.name}-vault"
  region             = "${var.region}"
  vpc_id             = "${var.vpc_id}"
  vpc_cidr           = "${var.vpc_cidr}"
  private_subnet_ids = "${var.private_subnet_ids}"
  public_subnet_ids  = "${var.public_subnet_ids}"
  ssl_cert           = "${var.ssl_cert}"
  ssl_key            = "${var.ssl_key}"
  key_name           = "${var.key_name}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  user_data          = "${var.vault_user_data}"
  instance_type      = "${var.vault_instance_type}"
  nodes              = "${var.vault_nodes}"
  amis               = "${var.vault_amis}"
  domain             = "${var.domain}"
  sub_domain         = "${var.sub_domain}"
  route_zone_id      = "${var.route_zone_id}"
}

# Consul
output "consul_private_ips" { value = "${module.consul.private_ips}" }

# Vault
output "vault_private_ips" { value = "${module.vault.private_ips}" }
output "vault_elb_dns"     { value = "${module.vault.elb_dns}" }
output "vault_private_fqdn" { value = "${module.vault.private_fqdn}" }
