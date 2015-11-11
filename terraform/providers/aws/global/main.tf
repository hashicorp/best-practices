variable "region" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "name" {}
variable "domain" {}
variable "admins" {}

# Provider
provider "aws" {
  region = "${var.region}"
}

atlas {
  name = "${var.atlas_username}/${var.atlas_environment}"
}

# IAM
resource "aws_iam_group" "admins" {
  name = "${var.name}-admins"
}

resource "aws_iam_group_policy" "admins" {
  name   = "${var.name}-admins"
  group  = "${aws_iam_group.admins.id}"
  policy = <<EOF
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

resource "aws_iam_user" "admins" {
  name   = "${element(split(",", var.admins), count.index)}"
  count  = "${length(split(",", var.admins))}"
}

resource "aws_iam_access_key" "admins" {
  user = "${element(aws_iam_user.admins.*.name, count.index)}"
  count  = "${length(split(",", var.admins))}"
}

resource "aws_iam_group_membership" "admins" {
  name  = "${var.name}-admins"
  group = "${aws_iam_group.admins.name}"
  users = ["${aws_iam_user.admins.*.name}"]
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

output "admin_iam_config" {
  value = <<IAMCONFIG

  Admins: ${join("\n          ", formatlist("%s", aws_iam_access_key.admins.*.user))}

  Access IDs: ${join("\n              ", formatlist("%s", aws_iam_access_key.admins.*.id))}

  Secret Keys: ${join("\n               ", formatlist("%s", aws_iam_access_key.admins.*.secret))}
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
