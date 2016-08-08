#--------------------------------------------------------------
# This module creates all resources necessary for Consul
#--------------------------------------------------------------

variable "base_name"           	{}
variable "nodes"              	{ default = "3" }
variable "project"        	{}
variable "region"        	{}
variable "atlas_username"    	{}
variable "atlas_environment"    {}
variable "atlas_token"		{}
variable "image"                {}
variable "subnetwork_name"	{}

resource "template_file" "consul_config" {
  template = "${path.module}/consul.sh.tpl"
  count = "${var.nodes}"

  vars {
    atlas_username      = "${var.atlas_username}"
    atlas_environment   = "${var.atlas_environment}"
    atlas_token         = "${var.atlas_token}"
    consul_server_count = "${var.nodes}"
    node_name           = "${var.base_name}-consul-${count.index}"
  }

  lifecycle { create_before_destroy = true }

}

resource "google_compute_instance" "consul" {
  name         	= "${var.base_name}-consul-${count.index}"
  count		= "${var.nodes}"
  machine_type 	= "n1-standard-1"
  zone         	= "us-central1-a"

  metadata_startup_script = "${element(template_file.consul_config.*.rendered, count.index)}"

  disk {
    image = "${var.image}"
  }

  network_interface {
    subnetwork = "${var.subnetwork_name}"

    access_config {
	# ephemeral
    }
  }

  # provisioner "remote-exec" {
  #   inline = "${data.template_file.consul_config.rendered}"
  # }

}

output "private_ips" { value = "${join(",", google_compute_instance.consul.*.network_interface.0.address)}" }
