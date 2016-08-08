#--------------------------------------------------------------

# This module creates all data resources

#--------------------------------------------------------------

variable "name" {}

variable "project" {}

variable "region" {}

variable "zone" {}

variable "atlas_username" {}

variable "atlas_environment" {}

variable "atlas_token" {}

variable "subnetwork" {}

variable "consul_image" {}

variable "consul_node_count" {}

variable "consul_instance_type" {}

variable "vault_ssl_cert" {}

variable "vault_ssl_key" {}

variable "vault_image" {}

variable "vault_node_count" {}

variable "vault_instance_type" {}

module "consul" {
  source = "./consul"

  name              = "${var.name}-consul"
  project           = "${var.project}"
  region            = "${var.region}"
  zone              = "${var.zone}"
  atlas_username    = "${var.atlas_username}"
  atlas_environment = "${var.atlas_environment}"
  atlas_token       = "${var.atlas_token}"
  subnetwork        = "${var.subnetwork}"
  image             = "${var.consul_image}"
  nodes             = "${var.consul_node_count}"
  instance_type     = "${var.consul_instance_type}"
}

module "vault" {
  source = "./vault"

  name    = "${var.name}-vault"
  project = "${var.project}"
  region  = "${var.region}"
  zone    = "${var.zone}"

  atlas_username    = "${var.atlas_username}"
  atlas_environment = "${var.atlas_environment}"
  atlas_token       = "${var.atlas_token}"
  subnetwork        = "${var.subnetwork}"
  ssl_cert          = "${var.vault_ssl_cert}"
  ssl_key           = "${var.vault_ssl_key}"
  image             = "${var.vault_image}"
  nodes             = "${var.vault_node_count}"
  instance_type     = "${var.vault_instance_type}"
}

# Consul
output "consul_private_ips" {
  value = "${module.consul.private_ips}"
}

# Vault
output "vault_private_ips" {
  value = "${module.vault.private_ips}"
}
