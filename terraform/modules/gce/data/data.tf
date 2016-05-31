#--------------------------------------------------------------
# This module creates all data resources
#--------------------------------------------------------------

variable "name"               { }
variable "zone"               { }
variable "network"            { }
variable "private_subnet_ids" { }
variable "public_subnet"      { }
variable "ssl_cert"           { }
variable "ssl_key"            { }
variable "atlas_username"     { }
variable "atlas_environment"  { }
variable "atlas_token"        { }
variable "sub_domain"         { }
variable "managed_zone"       { }

variable "consul_image"         { }
variable "consul_node_count"    { }
variable "consul_machine_type"  { }
variable "openvpn_user"         { }
variable "openvpn_host"         { }
variable "private_key"          { }
variable "bastion_host"         { }
variable "bastion_user"         { }

variable "vault_image"          { }
variable "vault_node_count"     { }
variable "vault_machine_type"   { }

module "consul" {
  source = "./consul"

  name               = "${var.name}-consul"
  network            = "${var.network}"
  zone               = "${var.zone}"
  public_subnet      = "${var.public_subnet}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  image              = "${var.consul_image}"
  nodes              = "${var.consul_node_count}"
  machine_type       = "${var.consul_machine}"
  openvpn_user       = "${var.openvpn_user}"
  openvpn_host       = "${var.openvpn_host}"
  private_key        = "${var.private_key}"
  bastion_host       = "${var.bastion_host}"
  bastion_user       = "${var.bastion_user}"
}

module "vault" {
  source = "./vault"

  name               = "${var.name}-vault"
  zone               = "${var.zone}"
  network            = "${var.network}"
  public_subnet      = "${var.public_subnet}"
  ssl_cert           = "${var.ssl_cert}"
  ssl_key            = "${var.ssl_key}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  image              = "${var.vault_image}"
  nodes              = "${var.vault_node_count}"
  machine_type       = "${var.vault_machine_type}"
  sub_domain         = "${var.sub_domain}"
  managed_zone       = "${var.managed_zone}"
}

# Consul
output "consul_private_ips" { value = "${module.consul.private_ips}" }

# Vault
output "vault_private_ips"  { value = "${module.vault.private_ips}" }
output "vault_private_fqdn" { value = "${module.vault.fqdn}" }
