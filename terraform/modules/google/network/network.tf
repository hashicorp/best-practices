variable "name" {}

variable "region" {}

variable "zones" {
  type = "list"
}

variable "cidr" {}

variable "public_subnets" {
  type = "list"
}

variable "private_subnets" {
  type = "list"
}

variable "bastion_image" {}

variable "bastion_instance_type" {}

variable "ssh_keys" {}

resource "google_compute_network" "network" {
  name = "${var.name}"
}

resource "google_compute_firewall" "allow-internal" {
  name    = "${var.name}-allow-internal"
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
    "${var.cidr}",
  ]
}

resource "google_compute_firewall" "allow-ssh" {
  name    = "${var.name}-allow-ssh"
  network = "${google_compute_network.network.name}"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]

  # uncomment to restrict public ssh to the bastion host
  target_tags = ["bastion"]
}

module "public_subnet" {
  source = "./public_subnet"

  name    = "${var.name}-public"
  region  = "${var.region}"
  network = "${google_compute_network.network.self_link}"
  cidrs   = "${var.public_subnets}"
}

module "private_subnet" {
  source = "./private_subnet"

  name    = "${var.name}-private"
  region  = "${var.region}"
  network = "${google_compute_network.network.self_link}"
  cidrs   = "${var.private_subnets}"
}

module "bastion" {
  source = "./bastion"

  name                = "${var.name}-bastion"
  zones               = "${var.zones}"
  public_subnet_names = "${module.public_subnet.subnet_names}"
  image               = "${var.bastion_image}"
  instance_type       = "${var.bastion_instance_type}"
  ssh_keys            = "${var.ssh_keys}"
}

output "name" {
  value = "${google_compute_network.network.name}"
}

output "public_subnet_names" {
  value = "${module.public_subnet.subnet_names}"
}

output "private_subnet_names" {
  value = "${module.private_subnet.subnet_names}"
}

output "bastion_public_ip" {
  value = "${module.bastion.public_ip}"
}
