#--------------------------------------------------------------
# This module is used to achieve a blue/green deploy strategy
#--------------------------------------------------------------

variable "name"                { default = "deploy" }
variable "subnetwork"          { }
variable "zone"                { default = "us-central1-c" }
variable "blue_image"          { default = "ubuntu-1404-trusty-v20160406" }
variable "blue_nodes"          { }
variable "blue_machine_type"   { default = "g1-small" }
variable "blue_user_data"      { }
variable "green_image"         { default = "ubuntu-1404-trusty-v20160406" }
variable "green_nodes"         { }
variable "green_machine_type"  { default = "g1-small" }
variable "green_user_data"     { }

resource "google_compute_firewall" "deploy" {
  name        = "${var.name}"
  network     = "${var.network}"
  description = "Firewall rule for ${var.name} Blue/Green deploy Launch Configuration"

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }

  allow {
    protocol    = "icmp"
    //TODO Add target and source tags
  }
}

resource "google_compute_instance_template" "blue" {
  name            = "${var.name}-blue"
  image           = "${var.blue_image}"
  machine_type   = "${var.blue_machine_type}"

  disk {
    source_image = "${var.blue_image}"
    boot = true
  }

  network_interface {
    subnetwork = "${var.subnetwork}"
  }

  metadata {
    startup_script = "${var.blue_user_data}"
  }

  lifecycle { create_before_destroy = true }
}

resource "google_compute_group_manager" "blue" {
  name                  = "${var.name}-blue-group"
  base_instance_name    = "${google_compute_instance_template.blue.name}"
  instance_template     = "${google_compute_instance_template.blue.self_link}"
  zone                  = "${var.zone}"
  description           = "Managed group for blue instaces"
//TODO: Add target pools

  lifecycle { create_before_destroy = true }

}

resource "google_compute_autoscaler" "blue" {
  name    = "blue"
  zone    = "${var.zone}"
  target  = "${google_compute_group_manager.blue.self_link}"

  autocaling_policy {
    max_replicas      = "${var.blue_nodes}"
    min_replicas      = "${var.blue_nodes}"
    cooldown_prediod  = 60
  }
}

resource "google_compute_instance" "green" {
  name            = "${var.name}-green"
  image           = "${var.green_image}"
  machine_type    = "${var.green_machine_type}"

  disk {
    source_image = "${var.green_image}"
    boot = true
  }

  network_interface {
    subnetwork = "${var.subnetwork}"
  }

  metadata {
    startup_script = "${var.green_user_data}"
  }

  lifecycle { create_before_destroy = true }
}

resource "google_compute_group_manager" "green" {
  name                  = "${var.name}-green-group"
  base_instance_name    = "${google_compute_instance_template.green.name}"
  instance_template     = "${google_compute_instance_template.green.self_link}"
  zone                  = "${var.zone}"
  description           = "Managed group for green instaces"
//TODO: Add target pools

  lifecycle { create_before_destroy = true }

}

resource "google_compute_autoscaler" "green" {
  name    = "green"
  zone    = "${var.zone}"
  target  = "${google_compute_group_manager.green.self_link}"

  autocaling_policy {
    max_replicas      = "${var.green_nodes}"
    min_replicas      = "${var.green_nodes}"
    cooldown_prediod  = 60
  }
}
