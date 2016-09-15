variable "name" {}

variable "project" {}

variable "region" {}

variable "zones" {
  type = "list"
}

variable "credentials" {}

variable "atlas_username" {}

variable "atlas_environment" {}

variable "atlas_token" {}

variable "ssh_keys" {}

variable "cidr" {}

variable "private_subnets" {
  type = "list"
}

variable "public_subnets" {
  type = "list"
}

variable "consul_artifact_name" {}

variable "consul_node_count" {}

variable "consul_instance_type" {}

variable "vault_artifact_name" {}

variable "vault_node_count" {}

variable "vault_instance_type" {}

variable "vault_ssl_cert" {}

variable "vault_ssl_key" {}

variable "vault_token" {
  default = ""
}

variable "haproxy_artifact_name" {}

variable "haproxy_node_count" {}

variable "haproxy_instance_type" {}

variable "nodejs_artifact_name" {}

variable "nodejs_node_count" {}

variable "nodejs_instance_type" {}

variable "site_ssl_cert" {}

variable "site_ssl_key" {}

variable "bastion_image" {}

variable "bastion_instance_type" {}

provider "google" {
  credentials = "${var.credentials}"
  project     = "${var.project}"
  region      = "${var.region}"
}

atlas {
  name = "${var.atlas_username}/${var.atlas_environment}"
}

module "network" {
  source = "../../../modules/google/network"

  name            = "${var.name}"
  region          = "${var.region}"
  zones           = "${var.zones}"
  cidr            = "${var.cidr}"
  public_subnets  = "${var.public_subnets}"
  private_subnets = "${var.private_subnets}"
  ssh_keys        = "${var.ssh_keys}"

  bastion_image         = "${var.bastion_image}"
  bastion_instance_type = "${var.bastion_instance_type}"
}

data "atlas_artifact" "google-ubuntu-consul" {
  name  = "${var.atlas_username}/${var.consul_artifact_name}"
  type  = "google.image"
  build = "latest"
}

data "atlas_artifact" "google-ubuntu-vault" {
  name  = "${var.atlas_username}/${var.vault_artifact_name}"
  type  = "google.image"
  build = "latest"
}

module "data" {
  source = "../../../modules/google/data"

  name                 = "${var.name}"
  project              = "${var.project}"
  region               = "${var.region}"
  zones                = "${var.zones}"
  atlas_username       = "${var.atlas_username}"
  atlas_environment    = "${var.atlas_environment}"
  atlas_token          = "${var.atlas_token}"
  private_subnet_names = "${module.network.private_subnet_names}"
  public_subnet_names  = "${module.network.public_subnet_names}"
  ssh_keys             = "${var.ssh_keys}"

  consul_image         = "${data.atlas_artifact.google-ubuntu-consul.id}"
  consul_node_count    = "${var.consul_node_count}"
  consul_instance_type = "${var.consul_instance_type}"

  vault_image         = "${data.atlas_artifact.google-ubuntu-vault.id}"
  vault_node_count    = "${var.vault_node_count}"
  vault_instance_type = "${var.vault_instance_type}"
  vault_ssl_cert      = "${var.vault_ssl_cert}"
  vault_ssl_key       = "${var.vault_ssl_key}"
}

data "atlas_artifact" "google-ubuntu-haproxy" {
  name  = "${var.atlas_username}/${var.haproxy_artifact_name}"
  type  = "google.image"
  build = "latest"
}

data "atlas_artifact" "google-ubuntu-nodejs" {
  name  = "${var.atlas_username}/${var.nodejs_artifact_name}"
  type  = "google.image"
  build = "latest"
}

module "compute" {
  source = "../../../modules/google/compute"

  name                 = "${var.name}"
  zones                = "${var.zones}"
  atlas_username       = "${var.atlas_username}"
  atlas_environment    = "${var.atlas_environment}"
  atlas_token          = "${var.atlas_token}"
  network              = "${module.network.name}"
  private_subnet_names = "${module.network.private_subnet_names}"
  public_subnet_names  = "${module.network.public_subnet_names}"
  ssh_keys             = "${var.ssh_keys}"

  haproxy_image         = "${data.atlas_artifact.google-ubuntu-haproxy.id}"
  haproxy_node_count    = "${var.haproxy_node_count}"
  haproxy_instance_type = "${var.haproxy_instance_type}"

  nodejs_image         = "${data.atlas_artifact.google-ubuntu-nodejs.id}"
  nodejs_node_count    = "${var.nodejs_node_count}"
  nodejs_instance_type = "${var.nodejs_instance_type}"
  site_ssl_cert        = "${var.site_ssl_cert}"
  site_ssl_key         = "${var.site_ssl_key}"
  vault_ssl_cert       = "${var.vault_ssl_cert}"
  vault_token          = "${var.vault_token}"
}

output "configuration" {
  value = <<CONFIGURATION

Visit the Node.js website:
  HAProxy: ${join("\n           ", formatlist("http://%s/", module.compute.haproxy_public_ips))}

Add your private key and SSH into any private node via the Bastion host:
  ssh -A ubuntu@${module.network.bastion_public_ip}

Private node IPs:
  Node.js: ${join("\n           ", formatlist("ssh ubuntu@%s", module.compute.nodejs_private_ips))}

  HAProxy: ${join("\n           ", formatlist("ssh ubuntu@%s", module.compute.haproxy_private_ips))}

  Consul: ${join("\n          ", formatlist("ssh ubuntu@%s", module.data.consul_private_ips))}

  Vault: ${join("\n         ", formatlist("ssh ubuntu@%s", module.data.vault_private_ips))}
CONFIGURATION
}
