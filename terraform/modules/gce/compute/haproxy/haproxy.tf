#--------------------------------------------------------------
# This module creates all resources necessary for HAProxy
#--------------------------------------------------------------

variable "name"              { default = "haproxy" }
variable "network"           { }
variable "key_name"          { }
variable "public_subnet"     { }
variable "atlas_username"    { }
variable "atlas_environment" { }
variable "atlas_token"       { }
variable "image_url"         { }
variable "nodes"             { }
variable "machine_type"      { default = "g1-small"}
variable "sub_domain"        { }
variable "managed_zone"      { }
variable "zone"              { }

resource "google_compute_firewall" "haproxy" {
  name        = "${var.name}"
  network     = "${var.network}"
  description = "HAProxy security group"

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }

  allow {
    protocol    = "tcp"
    ports       = ["80","443"]
    //TODO Add target and source tags
  }

  allow {
    protocol    = "icmp"
    source_tags = ["private_subnet"]
    //TODO add tags to subnets
  }
}

resource "template_file" "user_data" {
  template = "${path.module}/haproxy.sh.tpl"
  count    = "${var.nodes}"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}-${count.index+1}"
  }
}

resource "google_compute_instance" "haproxy" {
  name                        = "${var.name}"
  count                       = "${var.nodes}"
  machine_type                = "${var.machine_type}"
  zone                        = "${var.zone}"
  metadata_startup_script     = "${element(template_file.user_data.*.rendered, count.index)}"
  can_ip_forward              = "true"

  disk {
    image = "${var.image_url}"
  }

  network_interface {
    subnetwork = "${module.public_subnet.name}"
    access_config {
    }
    // GCE is currently limited to one interface per setup.
    // https://www.terraform.io/docs/providers/google/r/compute_instance.html#network_interface

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }
}

resource "google_dns_record_set" "haproxy_public" {
  managed_zone = "${var.managed_zone}"
  name         = "haproxy.${var.sub_domain}"
  type         = "A"
  ttl          = "300"
  rrdata       = ["${google_compute_instance.haproxy.*.network_interface.*.access_config.assigned_nat_ip}"]
}

output "public_ips"   { value = "${join(",", google_compute_instance.haproxy.*.network_interface.*.access_config.assigned_nat_ip)}" }
output "public_fqdn"  { value = "${google_dns_record_set.haproxy_public.name}" }
