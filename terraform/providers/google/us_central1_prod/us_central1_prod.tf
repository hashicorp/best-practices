variable "name" {}

variable "project" {}

variable "region" {}

variable "zone" {}

variable "credentials" {}

variable "atlas_username" {}

variable "atlas_environment" {}

variable "atlas_token" {}

variable "cidr" {}

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
variable "haproxy_node_count"    { }
variable "haproxy_instance_type" { }

variable "nodejs_artifact_name"          { }
variable "nodejs_node_count"    { }
variable "nodejs_instance_type" { }
variable "site_ssl_cert"     { }
variable "site_ssl_key" { }

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

  name   = "${var.name}"
  region = "${var.region}"
  cidr   = "${var.cidr}"
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

  name              = "${var.name}"
  project           = "${var.project}"
  region            = "${var.region}"
  zone              = "${var.zone}"
  atlas_username    = "${var.atlas_username}"
  atlas_environment = "${var.atlas_environment}"
  atlas_token       = "${var.atlas_token}"
  subnetwork        = "${module.network.subnetwork_name}"

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

  name              = "${var.name}"
  zone              = "${var.zone}"
  atlas_username    = "${var.atlas_username}"
  atlas_environment = "${var.atlas_environment}"
  atlas_token       = "${var.atlas_token}"
  subnetwork        = "${module.network.subnetwork_name}"

  haproxy_image         = "${data.atlas_artifact.google-ubuntu-haproxy.id}"
  haproxy_node_count    = "${var.haproxy_node_count}"
  haproxy_instance_type = "${var.haproxy_instance_type}"

  nodejs_image         = "${data.atlas_artifact.google-ubuntu-nodejs.id}"
  nodejs_node_count    = "${var.nodejs_node_count}"
  nodejs_instance_type = "${var.nodejs_instance_type}"
  site_ssl_cert = "${var.site_ssl_cert}"
  site_ssl_key = "${var.site_ssl_key}"
  vault_ssl_cert = "${var.vault_ssl_cert}"
  vault_token = "${var.vault_token}"
}


