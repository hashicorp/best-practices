variable "region" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "name" {}
variable "domain" {}
variable "admins" {}

provider "aws" {
  region = "${var.region}"
}

atlas {
  name = "${var.atlas_username}/${var.atlas_environment}"
}

module "iam_admins" {
  source = "../../../modules/aws/util/iam"

  name       = "${var.name}-admins"
  users      = "${var.admins}"
  policy     = <<EOF
{
  "Version"  : "2012-10-17",
  "Statement": [
    {
      "Effect"  : "Allow",
      "Action"  : "*",
      "Resource": "*"
    }
  ]
}
EOF
}

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

output "iam_config" {
  value = <<IAMCONFIG

Admin IAM:
  Admin Users: ${join("\n               ", formatlist("%s", split(",", module.iam_admins.users)))}

  Access IDs: ${join("\n              ", formatlist("%s", split(",", module.iam_admins.access_ids)))}

  Secret Keys: ${join("\n               ", formatlist("%s", split(",", module.iam_admins.secret_keys)))}
IAMCONFIG
}

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
