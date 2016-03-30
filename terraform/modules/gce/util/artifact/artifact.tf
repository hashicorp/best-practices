#--------------------------------------------------------------
# This module is used to for creating Atlas artifacts
#--------------------------------------------------------------

variable "type"             { default = "google.image" }
variable "region"           { }
variable "atlas_username"   { }
variable "artifact_name"    { }
variable "artifact_version" { default = "latest" }

resource "atlas_artifact" "artifact" {
  name    = "${var.atlas_username}/${var.artifact_name}"
  type    = "${var.type}"
  count   = "${length(split(",", var.artifact_version))}"
  version = "${element(split(",", var.artifact_version), count.index)}"

  lifecycle { create_before_destroy = true }
  metadata  { region = "${var.region}" }
}

output "image_url" { value = "${join(",", atlas_artifact.artifact.*.metadata_full.id)}" }
