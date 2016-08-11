variable "name" {}

variable "region" {}

variable "network" {}

variable "cidrs" {}

resource "google_compute_subnetwork" "public" {
  name          = "${var.name}-${count.index}"
  count 		= "${length(split(",", var.cidrs))}"
  ip_cidr_range = "${element(split(",", var.cidrs), count.index)}"
  network       = "${var.network}"
  region        = "${var.region}"
}

output "subnet_names" {
  value = "${join(",", google_compute_subnetwork.public.*.name)}"
}
