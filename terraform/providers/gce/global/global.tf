variable "domain"            { }
variable "atlas_username"    { }
variable "atlas_environment" { }
variable "name"              { }
variable "region"            { }
variable "iam_admins"        { }
variable "iam_vault_envs"    { }

provider "aws" {
  region = "${var.region}"
}

atlas {
  name = "${var.atlas_username}/${var.atlas_environment}"
}

module "iam_admin" {
  source = "../../../modules/aws/util/iam"

  name       = "${var.name}-admin"
  users      = "${var.iam_admins}"
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

module "iam_vault" {
  source = "../../../modules/aws/util/iam"

  name       = "${var.name}-vault"
  users      = "${var.iam_vault_envs}"
  policy     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateAccessKey",
        "iam:CreateUser",
        "iam:PutUserPolicy",
        "iam:ListGroupsForUser",
        "iam:ListUserPolicies",
        "iam:ListAccessKeys",
        "iam:ListAttachedUserPolicies",
        "iam:DeleteAccessKey",
        "iam:DeleteUserPolicy",
        "iam:RemoveUserFromGroup",
        "iam:DeleteUser"
      ],
      "Resource": [
        "*"
      ]
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

output "config" {
  value = <<CONFIG

DNS records have been set in Route53, add NS records for ${var.domain} pointing to:
  ${join("\n  ", formatlist("%s", aws_route53_zone.zone.*.name_servers))}

Admin IAM:
  Admin Users: ${join("\n               ", formatlist("%s", split(",", module.iam_admin.users)))}

  Access IDs: ${join("\n              ", formatlist("%s", split(",", module.iam_admin.access_ids)))}

  Secret Keys: ${join("\n               ", formatlist("%s", split(",", module.iam_admin.secret_keys)))}

Vault IAM:
  Vault Users: ${join("\n               ", formatlist("%s", split(",", module.iam_vault.users)))}

  Access IDs: ${join("\n              ", formatlist("%s", split(",", module.iam_vault.access_ids)))}

  Secret Keys: ${join("\n               ", formatlist("%s", split(",", module.iam_vault.secret_keys)))}
CONFIG
}

output "iam_admin_users"       { value = "${module.iam_admin.users}" }
output "iam_admin_access_ids"  { value = "${module.iam_admin.access_ids}" }
output "iam_admin_secret_keys" { value = "${module.iam_admin.secret_keys}" }
output "iam_vault_users"       { value = "${module.iam_vault.users}" }
output "iam_vault_access_ids"  { value = "${module.iam_vault.access_ids}" }
output "iam_vault_secret_keys" { value = "${module.iam_vault.secret_keys}" }

output "prod_domain"      { value = "${module.prod_website.domain}" }
output "prod_endpoint"    { value = "${module.prod_website.endpoint}" }
output "prod_fqdn"        { value = "${module.prod_website.fqdn}" }
output "prod_zone_id"     { value = "${module.prod_website.hosted_zone_id}" }
output "staging_domain"   { value = "${module.staging_website.domain}" }
output "staging_endpoint" { value = "${module.staging_website.endpoint}" }
output "staging_fqdn"     { value = "${module.staging_website.fqdn}" }
output "staging_zone_id"  { value = "${module.staging_website.hosted_zone_id}" }

output "zone_id" { value = "${aws_route53_zone.zone.zone_id}" }
