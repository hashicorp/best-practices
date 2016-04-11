#--------------------------------------------------------------
# This module creates all resources necessary for a public
# subnet
#--------------------------------------------------------------

variable "name"           { default = "public" }
variable "network"        { }
variable "ip_cidr_range"  { }
variable "region"         { }

resource "google_compute_subnetwork" "public" {
  name              = "${var.name}"
  ip_cidr_range     = "${var.ip_cidr_range}"
  region            = "${var.region}"

  lifecycle { create_before_destroy = true }
}

output "subnet_ip_cidr" { value = "${google_compute_subnetwork.public.ip_cidr_range}" }
output "subnet_gateway" { value = "${google_compute_subnetwork.public.gateway_address}" }
