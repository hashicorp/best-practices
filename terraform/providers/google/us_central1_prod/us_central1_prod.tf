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
