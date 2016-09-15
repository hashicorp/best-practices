#--------------------------------------------------------------

# This module creates all resources necessary for a Bastion

# host

#--------------------------------------------------------------

variable "name" {}

variable "zones" {
  type = "list"
}

variable "public_subnet_names" {
  type = "list"
}

variable "image" {}

variable "instance_type" {}

variable "ssh_keys" {}

resource "google_compute_instance" "bastion" {
  name         = "${var.name}"
  machine_type = "${var.instance_type}"
  zone         = "${element(var.zones, 0)}"

  metadata {
    sshKeys = "${var.ssh_keys}"
  }

  disk {
    image = "${var.image}"
  }

  network_interface {
    subnetwork = "${element(var.public_subnet_names, 0)}"

    access_config {
      # ephemeral
    }
  }

  tags = ["bastion"]
}

output "private_ip" {
  value = "${google_compute_instance.bastion.network_interface.0.address}"
}

output "public_ip" {
  value = "${google_compute_instance.bastion.network_interface.0.access_config.0.assigned_nat_ip}"
}
