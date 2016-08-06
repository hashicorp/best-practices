variable "base_name"  {}
variable "region" {}
variable "cidr" {}

resource "google_compute_network" "network" {
  name       = "${var.base_name}-network"
}

resource "google_compute_subnetwork" "default-us-central1" {
  name    = "${var.base_name}-subnetwork"
  ip_cidr_range = "${var.cidr}"
  network       = "${google_compute_network.network.self_link}"
  region        = "${var.region}"
}

resource "google_compute_firewall" "allow-internal" {
  name    = "${var.base_name}-network-allow-internal"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [
    "${var.cidr}"
  ]
}

resource "google_compute_firewall" "allow-ssh" {
  name    = "${var.base_name}-network-allow-ssh"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

output "name"     { value = "${google_compute_network.network.name}" }
output "subnetwork_name" { value = "${google_compute_subnetwork.default-us-central1.name}" }
