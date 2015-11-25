variable "type" { default = "amazon.ami" }
variable "region" {}
variable "atlas_username" {}
variable "latest_name" {}
variable "pinned_name" {}
variable "pinned_version" { default = "latest" }

resource "atlas_artifact" "latest" {
  name     = "${var.atlas_username}/${var.latest_name}"
  type     = "${var.type}"
  version  = "latest"

  lifecycle { create_before_destroy = true }

  metadata {
    region = "${var.region}"
  }
}

resource "atlas_artifact" "pinned" {
  name     = "${var.atlas_username}/${var.pinned_name}"
  type     = "${var.type}"
  version  = "${var.pinned_version}"

  lifecycle { create_before_destroy = true }

  metadata {
    region = "${var.region}"
  }
}

output "latest" { value = "${atlas_artifact.latest.metadata_full.ami_id}" }
output "pinned" { value = "${atlas_artifact.pinned.metadata_full.ami_id}" }
