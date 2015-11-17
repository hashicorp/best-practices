variable "region" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "name" {}
variable "domain" {}
variable "admins" {}
variable "account_id" {}

# Provider
provider "aws" {
  region = "${var.region}"
}

atlas {
  name = "${var.atlas_username}/${var.atlas_environment}"
}

# IAM
module "iam" {
  source = "./iam"

  name       = "${var.name}"
  admins     = "${var.admins}"
  account_id = "${var.account_id}"
}

# DNS/Website
resource "aws_route53_zone" "zone" {
  name = "${var.domain}"
}

module "prod_website" {
  source = "../../../modules/aws/util/website"

  route_zone_id = "${aws_route53_zone.zone.zone_id}"
  fqdn          = "${var.domain}"
  sub_domain    = "${var.domain}"
}

module "staging_website" {
  source = "../../../modules/aws/util/website"

  route_zone_id = "${aws_route53_zone.zone.zone_id}"
  fqdn          = "staging.${var.domain}"
  sub_domain    = "staging"
}

output "iam_admin_config" {
  value = <<IAMCONFIG

Admin IAM:
  Admin Users: ${join("\n               ", formatlist("%s", split(",", module.iam.admin_users)))}

  Access IDs: ${join("\n              ", formatlist("%s", split(",", module.iam.admin_access_ids)))}

  Secret Keys: ${join("\n               ", formatlist("%s", split(",", module.iam.admin_secret_keys)))}

Vault IAM:
  Vault User: ${join("\n              ", formatlist("%s", split(",", module.iam.vault_user)))}

  Access ID: ${join("\n             ", formatlist("%s", split(",", module.iam.vault_access_id)))}

  Secret Key: ${join("\n              ", formatlist("%s", split(",", module.iam.vault_secret_key)))}
IAMCONFIG
}

output "iam_vault_user"       { value = "${module.iam.vault_user}" }
output "iam_vault_access_id"  { value = "${module.iam.vault_access_id}" }
output "iam_vault_secret_key" { value = "${module.iam.vault_secret_key}" }

output "nameserver_config" {
  value = <<NAMESERVERCONFIG

DNS records have been set in Route53, add NS records for ${var.domain} pointing to:
  ${join("\n  ", formatlist("%s", aws_route53_zone.zone.*.name_servers))}
NAMESERVERCONFIG
}

output "prod_domain"      { value = "${module.prod_website.domain}" }
output "prod_endpoint"    { value = "${module.prod_website.endpoint}" }
output "prod_fqdn"        { value = "${module.prod_website.fqdn}" }
output "prod_zone_id"     { value = "${module.prod_website.hosted_zone_id}" }
output "staging_domain"   { value = "${module.staging_website.domain}" }
output "staging_endpoint" { value = "${module.staging_website.endpoint}" }
output "staging_fqdn"     { value = "${module.staging_website.fqdn}" }
output "staging_zone_id"  { value = "${module.staging_website.hosted_zone_id}" }
output "zone_id"          { value = "${aws_route53_zone.zone.zone_id}" }
