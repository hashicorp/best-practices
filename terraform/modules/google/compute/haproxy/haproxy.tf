#--------------------------------------------------------------

# This module creates all resources necessary for HAProxy

#--------------------------------------------------------------

variable "name" {}

variable "zones" {
  type = "list"
}

variable "atlas_username" {}

variable "atlas_environment" {}

variable "atlas_token" {}

variable "network" { default = "default" }

variable "public_subnet_names" {
  type = "list"
}

variable "image" {}

variable "nodes" {}

variable "instance_type" {}

variable "ssh_keys" {}

resource "template_file" "haproxy_config" {
  template = "${file("${path.module}/haproxy.sh.tpl")}"
  count    = "${var.nodes}"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}-${count.index}"
  }
}

resource "google_compute_instance" "haproxy" {
  name         = "${var.name}-${count.index}"
  count        = "${var.nodes}"
  machine_type = "${var.instance_type}"
  zone         = "${element(var.zones, count.index)}"

  metadata_startup_script = "${element(template_file.haproxy_config.*.rendered, count.index)}"

  metadata {
    sshKeys = "${var.ssh_keys}"
  }

  disk {
    image = "${var.image}"
  }

  network_interface {
    subnetwork = "${element(var.public_subnet_names, count.index)}"

    access_config {
      # ephemeral
    }
  }

  tags = ["${var.name}", "haproxy"]
}

resource "google_compute_firewall" "allow-http" {
  name    = "${var.name}-allow-http"
  network = "${var.network}"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.name}"]
}

output "private_ips" {
  value = ["${google_compute_instance.haproxy.*.network_interface.0.address}"]
}

output "public_ips" {
  value = ["${google_compute_instance.haproxy.network_interface.0.access_config.0.assigned_nat_ip}"]
}
