variable "project"        {}
variable "region"        {}
variable "credentials"        {}
variable "atlas_username"    {}
variable "atlas_environment"    {}
variable "atlas_token"		{}
variable "base_name" {}
variable "cidr"            {}

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

  base_name = "${var.base_name}"
  region = "${var.region}"
  cidr = "${var.cidr}"
}

resource "atlas_artifact" "google-ubuntu-consul" {
  name = "${var.atlas_username}/google-ubuntu-consul"
  type = "google.image"
  version = "latest"
}

module "consul" {
  source = "../../../modules/google/consul"

  project = "${var.project}"
  region = "${var.region}"
  credentials = "${var.credentials}"
  atlas_username = "${var.atlas_username}"
  atlas_environment = "${var.atlas_environment}"
  atlas_token = "${var.atlas_token}"
  base_name = "${var.base_name}"
  cidr = "${var.cidr}"
  image = "${atlas_artifact.google-ubuntu-consul.id}"
  subnetwork_name = "${module.network.subnetwork_name}"
}
