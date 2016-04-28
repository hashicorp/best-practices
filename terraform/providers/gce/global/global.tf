variable "domain"            { }
variable "atlas_username"    { }
variable "atlas_environment" { }
variable "name"              { }
variable "region"            { }
variable "project"           { }

provider "google" {
  region  = "${var.region}"
  project = "${var.project}"
}

atlas {
  name = "${var.atlas_username}/${var.atlas_environment}"
}

resource "google_dns_managed_zone" "zone" {
  name     = "${var.name}"
  dns_name = "${var.domain}."
}

module "prod_website" {
  source = "../../../modules/gce/util/website"

  managed_zone  = "${google_dns_managed_zone.zone.name}"
  fqdn          = "${var.domain}"
  sub_domain    = "${var.domain}"
}

module "staging_website" {
  source = "../../../modules/gce/util/website"

  managed_zone  = "${google_dns_managed_zone.zone.name}"
  fqdn          = "staging.${var.domain}"
  sub_domain    = "staging"
}

output "config" {
  value = <<CONFIG

DNS records have been set in Google Cloud DNS, add NS records for ${var.domain} pointing to:
  ${join("\n  ", formatlist("%s", google_dns_managed_zone.zone.*.name_servers))}

CONFIG
}

output "prod_bucket"        { value = "${module.prod_website.bucket}" }
output "prod_bucket_uri"    { value = "${module.prod_website.bucket_uri}" }
output "prod_fqdn"          { value = "${module.prod_website.fqdn}" }
output "staging_bucket"     { value = "${module.staging_website.bucket}" }
output "staging_bucket_uri" { value = "${module.staging_website.bucket_uri}" }
output "staging_fqdn"       { value = "${module.staging_website.fqdn}" }

output "managed_zone" { value = "${google_dns_managed_zone.zone.name}" }
