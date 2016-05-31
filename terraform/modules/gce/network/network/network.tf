#--------------------------------------------------------------
# This module creates all resources necessary for a Network
#--------------------------------------------------------------

variable "name"                    { default = "default_network" }
variable "auto_create_subnetworks" { default = "true" }

resource "google_compute_network" "network" {
  name =                  = "${var.name}"
  auto_create_subnetworks = "${var.auto_create_subnetworks}"

  lifecycle { create_before_destroy = true }
}

output "network_name"   { value = "${google_compute_network.network.name}" }
output "network_cidr"   { value = "${google_compute_network.network.ipv4_range}" }
output "network_uri"    { value = "${google_compute_network.network.self_link}" }
