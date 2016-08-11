#--------------------------------------------------------------
# This module creates all resources necessary for the
# Node.js application
#--------------------------------------------------------------

variable "name"                { }
variable "zone"              { }
variable "atlas_username"      { }
variable "atlas_environment"   { }
variable "atlas_token"         { }
variable "subnetwork" {}
variable "image"            { }
variable "nodes"          { }
variable "instance_type"  { }

variable "site_ssl_cert"       { }
variable "site_ssl_key"        { }
variable "vault_ssl_cert"      { }

variable "vault_token"         { default = "" }
variable "vault_policy"        { default = "nodejs" }

resource "template_file" "nodejs_config" {
  template = "${path.module}/nodejs.sh.tpl"
  count    = "${var.nodes}"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}-${count.index}"
    deploy            = "deploy"
    site_ssl_cert     = "${var.site_ssl_cert}"
    vault_ssl_cert    = "${var.vault_ssl_cert}"
    vault_token       = "${var.vault_token}"
    vault_policy      = "${var.vault_policy}"
  }
}

resource "google_compute_instance" "nodejs" {
  name         = "${var.name}-${count.index}"
  count        = "${var.nodes}"
  machine_type = "${var.instance_type}"
  zone         = "${var.zone}"

  metadata_startup_script = "${element(template_file.nodejs_config.*.rendered, count.index)}"

  disk {
    image = "${var.image}"
  }

  network_interface {
    subnetwork = "${var.subnetwork}"

    access_config {
      # ephemeral
    }
  }
}

output "private_ips" {
  value = "${join(",", google_compute_instance.nodejs.*.network_interface.0.address)}"
}