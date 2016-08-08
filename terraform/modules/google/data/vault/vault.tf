#--------------------------------------------------------------

# This module creates all resources necessary for Vault 

#--------------------------------------------------------------

variable "name" {}

variable "project" {}

variable "region" {}

variable "zone" {}

variable "atlas_username" {}

variable "atlas_environment" {}

variable "atlas_token" {}

variable "subnetwork" {}

variable "image" {}

variable "nodes" {}

variable "instance_type" {}

variable "ssl_cert" {}

variable "ssl_key" {}

resource "template_file" "vault_config" {
  template = "${path.module}/vault.sh.tpl"
  count    = "${var.nodes}"

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}-${count.index}"
    ssl_cert          = "${var.ssl_cert}"
    ssl_key           = "${var.ssl_key}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance" "vault" {
  name         = "${var.name}-${count.index}"
  count        = "${var.nodes}"
  machine_type = "${var.instance_type}"
  zone         = "${var.zone}"

  metadata_startup_script = "${element(template_file.vault_config.*.rendered, count.index)}"

  disk {
    image = "${var.image}"
  }

  network_interface {
    subnetwork = "${var.subnetwork}"

    access_config {
      # ephemeral
    }
  }
}

output "private_ips" {
  value = "${join(",", google_compute_instance.vault.*.network_interface.0.address)}"
}
