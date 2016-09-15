#--------------------------------------------------------------

# This module creates all compute resources

#--------------------------------------------------------------

variable "name" {}

variable "zones" {
  type = "list"
}

variable "atlas_username" {}

variable "atlas_environment" {}

variable "atlas_token" {}

variable "network" { default = "default" }

variable "private_subnet_names" {
  type = "list"
}

variable "public_subnet_names" {
  type = "list"
}

variable "haproxy_image" {}

variable "haproxy_node_count" {}

variable "haproxy_instance_type" {}

variable "nodejs_image" {}

variable "nodejs_node_count" {}

variable "nodejs_instance_type" {}

variable "site_ssl_cert" {}

variable "site_ssl_key" {}

variable "vault_ssl_cert" {}

variable "vault_token" {}

variable "ssh_keys" {}

module "haproxy" {
  source = "./haproxy"

  name                 = "${var.name}-haproxy"
  zones                = "${var.zones}"
  atlas_username       = "${var.atlas_username}"
  atlas_environment    = "${var.atlas_environment}"
  atlas_token          = "${var.atlas_token}"
  network              = "${var.network}"
  public_subnet_names  = "${var.public_subnet_names}"
  image                = "${var.haproxy_image}"
  nodes                = "${var.haproxy_node_count}"
  instance_type        = "${var.haproxy_instance_type}"
  ssh_keys             = "${var.ssh_keys}"
}

module "nodejs" {
  source = "./nodejs"

  name                 = "${var.name}-nodejs"
  zones                = "${var.zones}"
  atlas_username       = "${var.atlas_username}"
  atlas_environment    = "${var.atlas_environment}"
  atlas_token          = "${var.atlas_token}"
  private_subnet_names = "${var.private_subnet_names}"
  public_subnet_names  = "${var.public_subnet_names}"
  image                = "${var.nodejs_image}"
  nodes                = "${var.nodejs_node_count}"
  instance_type        = "${var.nodejs_instance_type}"
  site_ssl_cert        = "${var.site_ssl_cert}"
  site_ssl_key         = "${var.site_ssl_key}"
  vault_ssl_cert       = "${var.vault_ssl_cert}"
  vault_token          = "${var.vault_token}"
  ssh_keys             = "${var.ssh_keys}"
}

output "haproxy_private_ips" {
  value = "${module.haproxy.private_ips}"
}

output "haproxy_public_ips" {
  value = "${module.haproxy.public_ips}"
}

output "nodejs_private_ips" {
  value = "${module.nodejs.private_ips}"
}
