variable "name" {}
variable "region" {}
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "key_name" {}
variable "azs" {}
variable "private_subnet_ids" {}
variable "public_subnet_ids" {}
variable "site_ssl_cert" {}
variable "site_ssl_key" {}
variable "vault_ssl_cert" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_token" {}
variable "domain" {}
variable "sub_domain" {}
variable "route_zone_id" {}
variable "vault_token" { default = "" }

variable "haproxy_user_data" {}
variable "haproxy_nodes" {}
variable "haproxy_amis" {}
variable "haproxy_instance_type" {}
variable "haproxy_sub_domain" {}

variable "nodejs_user_data" {}
variable "nodejs_nodes" {}
variable "nodejs_ami" {}
variable "nodejs_instance_type" {}

module "haproxy" {
  source = "haproxy"

  name               = "${var.name}-haproxy"
  vpc_id             = "${var.vpc_id}"
  vpc_cidr           = "${var.vpc_cidr}"
  key_name           = "${var.key_name}"
  subnet_ids         = "${var.public_subnet_ids}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  user_data          = "${var.haproxy_user_data}"
  nodes              = "${var.haproxy_nodes}"
  amis               = "${var.haproxy_amis}"
  instance_type      = "${var.haproxy_instance_type}"
  haproxy_sub_domain = "${var.haproxy_sub_domain}"
  domain             = "${var.domain}"
  sub_domain         = "${var.sub_domain}"
  route_zone_id      = "${var.route_zone_id}"
}

module "nodejs" {
  source = "nodejs"

  name               = "${var.name}-nodejs"
  region             = "${var.region}"
  vpc_id             = "${var.vpc_id}"
  vpc_cidr           = "${var.vpc_cidr}"
  key_name           = "${var.key_name}"
  azs                = "${var.azs}"
  private_subnet_ids = "${var.private_subnet_ids}"
  public_subnet_ids  = "${var.public_subnet_ids}"
  site_ssl_cert      = "${var.site_ssl_cert}"
  site_ssl_key       = "${var.site_ssl_key}"
  vault_ssl_cert     = "${var.vault_ssl_cert}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  user_data          = "${var.nodejs_user_data}"
  nodes              = "${var.nodejs_nodes}"
  ami                = "${var.nodejs_ami}"
  instance_type      = "${var.nodejs_instance_type}"
  domain             = "${var.domain}"
  sub_domain         = "${var.sub_domain}"
  route_zone_id      = "${var.route_zone_id}"
  vault_token        = "${var.vault_token}"
}

output "haproxy_private_ips"     { value = "${module.haproxy.private_ips}" }
output "haproxy_public_ips"      { value = "${module.haproxy.public_ips}" }
output "haproxy_private_fqdn"    { value = "${module.haproxy.private_fqdn}" }
output "haproxy_public_fqdn"     { value = "${module.haproxy.public_fqdn}" }

output "nodejs_zone_id"      { value = "${module.nodejs.zone_id}" }
output "nodejs_elb_dns"      { value = "${module.nodejs.elb_dns}" }
output "nodejs_private_fqdn" { value = "${module.nodejs.private_fqdn}" }
