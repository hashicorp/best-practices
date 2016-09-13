variable "name" {}

variable "region" {}

variable "network" {}

variable "cidrs" {
  type = "list"
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.name}-${count.index}"
  count         = "${length(var.cidrs)}"
  ip_cidr_range = "${element(var.cidrs, count.index)}"
  network       = "${var.network}"
  region        = "${var.region}"
}

output "subnet_names" {
  value = ["${google_compute_subnetwork.private.*.name}"]
}
