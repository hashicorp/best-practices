variable "project"        	{}
variable "region"        	{}	
variable "credentials"        	{}
variable "atlas_username"    	{}
variable "atlas_environment"    {}
variable "atlas_token"		{}
variable "base_name" 		{}
variable "cidr"            	{}
variable "vault_ssl_cert"    	{}
variable "vault_ssl_key"     	{}
variable "vault_token" 		{ default = "" }

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

data "atlas_artifact" "google-ubuntu-consul" {
    name = "${var.atlas_username}/google-ubuntu-consul"
    type = "google.image"
    build = "latest"
}

data "atlas_artifact" "google-ubuntu-vault" {
    name = "${var.atlas_username}/google-ubuntu-vault"
    type = "google.image"
    build = "latest"
}

module "consul" {
  source = "../../../modules/google/consul"

  project = "${var.project}"
  region = "${var.region}"
  atlas_username = "${var.atlas_username}"
  atlas_environment = "${var.atlas_environment}"
  atlas_token = "${var.atlas_token}"
  base_name = "${var.base_name}"
  image = "${data.atlas_artifact.google-ubuntu-consul.id}"
  subnetwork_name = "${module.network.subnetwork_name}"
}

module "vault" {
  source 		= "../../../modules/google/vault"
  project 		= "${var.project}"
  region 		= "${var.region}"
  atlas_username 	= "${var.atlas_username}"
  atlas_environment 	= "${var.atlas_environment}"
  atlas_token 		= "${var.atlas_token}"
  base_name 		= "${var.base_name}"
  image 		= "${data.atlas_artifact.google-ubuntu-vault.id}"
  subnetwork_name 	= "${module.network.subnetwork_name}"
  ssl_cert           	= "${var.vault_ssl_cert}"
  ssl_key 		= "${var.vault_ssl_key}"
}

