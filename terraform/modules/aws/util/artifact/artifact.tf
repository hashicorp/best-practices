#--------------------------------------------------------------
# This module is used to for creating Atlas artifacts
#--------------------------------------------------------------

variable "type"              { default = "amazon.ami" }
variable "region"            { }
variable "atlas_username"    { }
variable "artifact_name"     { }
variable "artifact_versions" { default = "latest" }

resource "atlas_artifact" "mod" {
  name    = "${var.atlas_username}/${var.artifact_name}"
  type    = "${var.type}"
  count   = "${length(split(",", var.artifact_versions))}"
  version = "${element(split(",", var.artifact_versions), count.index)}"

  lifecycle { create_before_destroy = true }

  metadata {
    region = "${var.region}"
  }
}

output "amis" { value = "${atlas_artifact.mod.metadata_full.*.ami_id}" }
