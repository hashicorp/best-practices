#--------------------------------------------------------------
# This module creates all compute resources
#--------------------------------------------------------------

variable "name"               { }
variable "zone" {}
variable "atlas_username"     { }
variable "atlas_environment"  { }
variable "atlas_token"        { }
variable "subnetwork" {}

variable "haproxy_image"          { }
variable "haproxy_node_count"    { }
variable "haproxy_instance_type" { }

module "haproxy" {
  source = "./haproxy"

  name               = "${var.name}-haproxy"
  zone               = "${var.zone}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  subnetwork         = "${var.subnetwork}"
  image              = "${var.haproxy_image}"
  nodes              = "${var.haproxy_node_count}"
  instance_type      = "${var.haproxy_instance_type}"
}

output "haproxy_private_ips"  { value = "${module.haproxy.private_ips}" }
