#--------------------------------------------------------------
# This module creates all resources necessary for a private
# subnet
#--------------------------------------------------------------

variable "name"           { default = "private" }
variable "network"        { }
variable "ip_cidr_range"  { }
variable "region"         { }

resource "google_compute_subnetwork" "private" {
  name              = "${var.name}"
  ip_cidr_range     = "${var.ip_cidr_range}"
  network           = "${var.network}"
  region            = "${var.region}"

  lifecycle { create_before_destroy = true }
}

output "subnet_ip_cidr" { value = "${google_compute_subnetwork.private.ip_cidr_range}" }
output "subnet_gateway" { value = "${google_compute_subnetwork.private.gateway_address}" }
