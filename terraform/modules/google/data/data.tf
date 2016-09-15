#--------------------------------------------------------------

# This module creates all data resources

#--------------------------------------------------------------

variable "name" {}

variable "project" {}

variable "region" {}

variable "zones" {
  type = "list"
}

variable "atlas_username" {}

variable "atlas_environment" {}

variable "atlas_token" {}

variable "private_subnet_names" {
  type = "list"
}

variable "public_subnet_names" {
  type = "list"
}

variable "consul_image" {}

variable "consul_node_count" {}

variable "consul_instance_type" {}

variable "vault_ssl_cert" {}

variable "vault_ssl_key" {}

variable "vault_image" {}

variable "vault_node_count" {}

variable "vault_instance_type" {}

variable "ssh_keys" {}

module "consul" {
  source = "./consul"

  name                 = "${var.name}-consul"
  project              = "${var.project}"
  region               = "${var.region}"
  zones                = "${var.zones}"
  atlas_username       = "${var.atlas_username}"
  atlas_environment    = "${var.atlas_environment}"
  atlas_token          = "${var.atlas_token}"
  private_subnet_names = "${var.private_subnet_names}"
  image                = "${var.consul_image}"
  nodes                = "${var.consul_node_count}"
  instance_type        = "${var.consul_instance_type}"
  ssh_keys             = "${var.ssh_keys}"
}

module "vault" {
  source = "./vault"

  name    = "${var.name}-vault"
  project = "${var.project}"
  region  = "${var.region}"
  zones   = "${var.zones}"

  atlas_username       = "${var.atlas_username}"
  atlas_environment    = "${var.atlas_environment}"
  atlas_token          = "${var.atlas_token}"
  private_subnet_names = "${var.private_subnet_names}"
  public_subnet_names  = "${var.public_subnet_names}"
  ssl_cert             = "${var.vault_ssl_cert}"
  ssl_key              = "${var.vault_ssl_key}"
  image                = "${var.vault_image}"
  nodes                = "${var.vault_node_count}"
  instance_type        = "${var.vault_instance_type}"
  ssh_keys             = "${var.ssh_keys}"
}

# Consul
output "consul_private_ips" {
  value = "${module.consul.private_ips}"
}

# Vault
output "vault_private_ips" {
  value = "${module.vault.private_ips}"
}
