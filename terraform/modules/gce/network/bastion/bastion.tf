#--------------------------------------------------------------
# This module creates all resources necessary for a Bastion
# host
#--------------------------------------------------------------

variable "name"               { default = "bastion" }
variable "network"            { }
variable "zone"               { }
variable "public_subnet"      { }
variable "image"              { default = "ubuntu-1404-trusty-v20160314"}
variable "machine_type"       { }

resource "google_compute_firewall" "bastion" {
  name          = "${var.name}"
  network       = "${var.network}"
  description   = "Bastion firewall"

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }

  allow {
    protocol    = "icmp"
    //TODO Add target and source tags
  }

  allow {
    protocol    = "tcp"
    ports       = ["22"]
  }
}

resource "google_compute_instance" "bastion" {
  machine_type  = "${var.machine_type}"
  zone          = "${var.zone}"

  disk {
    image = "${var.image}"
  }

  network_interface {
    subnetwork = "${module.public_subnet.name}"
    access_config {
    }
  }

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }
}

output "user"       { value = "ubuntu" }
output "private_ip" { value = "${aws_instance.bastion.private_ip}" }
output "public_ip"  { value = "${aws_instance.bastion.public_ip}" }
