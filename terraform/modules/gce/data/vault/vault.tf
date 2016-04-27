#--------------------------------------------------------------
# This module creates all resources necessary for Vault
#--------------------------------------------------------------

variable "name"               { default = "vault" }
variable "network"            { }
variable "zone"               { default = "us-central1-c" }
variable "public_subnet"      { }
variable "ssl_cert"           { }
variable "ssl_key"            { }
variable "key_name"           { }
variable "atlas_username"     { }
variable "atlas_environment"  { }
variable "atlas_token"        { }
variable "image"              { default = "ubuntu-1404-trusty-v20160406" }
variable "nodes"              { }
variable "machine_type"       { default = "n1-standard-1"}
variable "sub_domain"         { }
variable "managed_zone"       { }

resource "google_compute_firewall" "vault" {
  name        = "${var.name}"
  network      = "${var.network}"
  description = "Firewall rule for Vault"

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }

  allow {
    protocol    = "icmp"
  }
}

resource "template_file" "user_data" {
  count    = "${var.nodes}"
  template = "${path.module}/vault.sh.tpl"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}-${count.index+1}"
    ssl_cert          = "${var.ssl_cert}"
    ssl_key           = "${var.ssl_key}"
  }
}

resource "google_compute_instance" "vault" {
  count                   = "${var.nodes}"
  machine_type            = "${var.machine_type}"
  zone                    = "${var.zone}"
  key_name                = "${var.key_name}"
  metadata_startup_script = "${element(template_file.user_data.*.rendered, count.index)}"

  tags { Name = "${var.name}.${count.index+1}" }

  disk {
    image = "${var.image}"
  }

  network_interface {
    subnetwork = "${module.public_subnet.name}"
    access_config {
    }
  }

}

resource "google_dns_record_set" "vault" {
  managed_zone = "${var.managed_zone}"
  name    = "vault.${var.sub_domain}"
  type    = "A"
  ttl     = "300"
  rrdatas = ["${google_compute_instance.vault.0.network_interface.0.access_config.assigned_nat_ip}"]
}

output "private_ips"  { value = "${join(",", google_compute_instance.vault.*.network_interface.*.access_config.assigned_nat_ip)}" }
output "fqdn"         { value = "${google_dns_record_set.vault.name}" }
