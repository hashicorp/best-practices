#--------------------------------------------------------------
# This module creates all resources necessary for Consul
#--------------------------------------------------------------

variable "base_name"           	{}
variable "nodes"              	{ default = "3" }
variable "project"        	{}
variable "region"        	{}
variable "credentials"        	{}
variable "atlas_username"    	{}
variable "atlas_environment"    {}
variable "atlas_token"		{}
variable "cidr"         	{}
variable "image"                {}
variable "subnetwork_name"	{}

resource "template_file" "user_data" {
  count    = "${var.nodes}"
  template = "${path.module}/consul.sh.tpl"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username      = "${var.atlas_username}"
    atlas_environment   = "${var.atlas_environment}"
    atlas_token         = "${var.atlas_token}"
    consul_server_count = "${var.nodes}"
    node_name           = "${var.base_name}-consul-${count.index}"
  }
}

resource "google_compute_instance" "consul" {
  name         	= "${var.base_name}-consul-${count.index}"
  count		= "${var.nodes}"
  machine_type 	= "n1-standard-1"
  zone         	= "us-central1-a"

  disk {
    image = "${var.image}"
  }

  // Local SSD disk
  disk {
    type    = "local-ssd"
    scratch = true
  }

  network_interface {
    subnetwork = "${var.subnetwork_name}"

    access_config {
	# ephemeral
    }
  }
}

output "private_ips" { value = "${join(",", google_compute_instance.consul.*.network_interface.0.address)}" }
