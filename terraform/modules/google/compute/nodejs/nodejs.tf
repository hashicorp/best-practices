#--------------------------------------------------------------

# This module creates all resources necessary for the

# Node.js application

#--------------------------------------------------------------

variable "name" {}

variable "zones" {
  type = "list"
}

variable "atlas_username" {}

variable "atlas_environment" {}

variable "atlas_token" {}

variable "private_subnet_names" {
  type = "list"
}

variable "public_subnet_names" {
  type = "list"
}

variable "image" {}

variable "nodes" {}

variable "instance_type" {}

variable "site_ssl_cert" {}

variable "site_ssl_key" {}

variable "vault_ssl_cert" {}

variable "vault_token" {
  default = ""
}

variable "vault_policy" {
  default = "nodejs"
}

variable "ssh_keys" {}

resource "template_file" "nodejs_config" {
  template = "${file("${path.module}/nodejs.sh.tpl")}"
  count    = "${var.nodes}"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}-${count.index}"
    deploy            = "deploy"
    site_ssl_cert     = "${var.site_ssl_cert}"
    vault_ssl_cert    = "${var.vault_ssl_cert}"
    vault_token       = "${var.vault_token}"
    vault_policy      = "${var.vault_policy}"
  }
}

resource "google_compute_instance" "nodejs" {
  name         = "${var.name}-${count.index}"
  count        = "${var.nodes}"
  machine_type = "${var.instance_type}"
  zone         = "${element(var.zones, count.index)}"

  metadata_startup_script = "${element(template_file.nodejs_config.*.rendered, count.index)}"

  metadata {
    sshKeys = "${var.ssh_keys}"
  }

  disk {
    image = "${var.image}"
  }

  network_interface {
    subnetwork = "${element(var.private_subnet_names, count.index)}"

    access_config {
      # ephemeral
    }
  }

  tags = ["nodejs"]
}

output "private_ips" {
  value = ["${google_compute_instance.nodejs.*.network_interface.0.address}"]
}
