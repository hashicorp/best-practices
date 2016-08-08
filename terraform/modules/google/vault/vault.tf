#--------------------------------------------------------------
# This module creates all resources necessary for Vault 
#--------------------------------------------------------------

variable "base_name"            {}
variable "nodes"                { default = "2" }
variable "project"              {}
variable "region"               {}
variable "atlas_username"       {}
variable "atlas_environment"    {}
variable "atlas_token"          {}
variable "image"                {}
variable "subnetwork_name"      {}
variable "ssl_cert"		{}
variable "ssl_key"		{}

resource "template_file" "vault_config" {
  template = "${path.module}/vault.sh.tpl"
  count = "${var.nodes}"

  vars {
    atlas_username      = "${var.atlas_username}"
    atlas_environment   = "${var.atlas_environment}"
    atlas_token         = "${var.atlas_token}"
    node_name           = "${var.base_name}-vault-${count.index}"
    ssl_cert          	= "${var.ssl_cert}"
    ssl_key 		= "${var.ssl_key}"
  }

  lifecycle { create_before_destroy = true }

}

resource "google_compute_instance" "vault" {
  name          = "${var.base_name}-vault-${count.index}"
  count         = "${var.nodes}"
  machine_type  = "n1-standard-1"
  zone          = "us-central1-a"

  metadata_startup_script = "${element(template_file.vault_config.*.rendered, count.index)}"

  disk {
    image = "${var.image}"
  }

  network_interface {
    subnetwork = "${var.subnetwork_name}"

    access_config {
        # ephemeral
    }
  }

}

output "private_ips" { value = "${join(",", google_compute_instance.vault.*.network_interface.0.address)}" }
