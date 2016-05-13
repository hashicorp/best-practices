#--------------------------------------------------------------
# This module creates all compute resources
#--------------------------------------------------------------

variable "name"               { }
variable "zone"               { }
variable "network"            { }
variable "key_name"           { }
variable "public_subnet"      { }
variable "site_ssl_cert"      { }
variable "site_ssl_key"       { }
variable "vault_ssl_cert"     { }
variable "atlas_username"     { }
variable "atlas_environment"  { }
variable "atlas_aws_global"   { }
variable "atlas_token"        { }
variable "sub_domain"         { }
variable "managed_zone"       { }
variable "vault_token"        { default = "" }

variable "haproxy_image"          { }
variable "haproxy_node_count"    { }
variable "haproxy_machine_type" { }

variable "nodejs_blue_image"            { }
variable "nodejs_blue_node_count"     { }
variable "nodejs_blue_machine_type"  { }
variable "nodejs_blue_weight"         { }
variable "nodejs_green_image"           { }
variable "nodejs_green_node_count"    { }
variable "nodejs_green_machine_type" { }
variable "nodejs_green_weight"        { }

module "haproxy" {
  source = "./haproxy"

  name               = "${var.name}-haproxy"
  network            = "${var.network}"
  key_name           = "${var.key_name}"
  public_subnet      = "${var.public_subnet}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  image              = "${var.haproxy_image}"
  nodes              = "${var.haproxy_node_count}"
  machine_type       = "${var.haproxy_machine_type}"
  sub_domain         = "${var.sub_domain}"
  managed_zone       = "${var.managed_zone}"
}

module "nodejs" {
  source = "./nodejs"

  name                = "${var.name}-nodejs"
  region              = "${var.region}"
  vpc_id              = "${var.vpc_id}"
  vpc_cidr            = "${var.vpc_cidr}"
  key_name            = "${var.key_name}"
  azs                 = "${var.azs}"
  private_subnet_ids  = "${var.private_subnet_ids}"
  public_subnet_ids   = "${var.public_subnet_ids}"
  site_ssl_cert       = "${var.site_ssl_cert}"
  site_ssl_key        = "${var.site_ssl_key}"
  vault_ssl_cert      = "${var.vault_ssl_cert}"
  atlas_username      = "${var.atlas_username}"
  atlas_environment   = "${var.atlas_environment}"
  atlas_aws_global    = "${var.atlas_aws_global}"
  atlas_token         = "${var.atlas_token}"
  blue_weight         = "${var.nodejs_blue_weight}"
  blue_ami            = "${var.nodejs_blue_ami}"
  blue_nodes          = "${var.nodejs_blue_node_count}"
  blue_instance_type  = "${var.nodejs_blue_instance_type}"
  green_ami           = "${var.nodejs_green_ami}"
  green_nodes         = "${var.nodejs_green_node_count}"
  green_instance_type = "${var.nodejs_green_instance_type}"
  green_weight        = "${var.nodejs_green_weight}"
  sub_domain          = "${var.sub_domain}"
  route_zone_id       = "${var.route_zone_id}"
  vault_token         = "${var.vault_token}"
}

output "haproxy_private_ips"  { value = "${module.haproxy.private_ips}" }
output "haproxy_public_ips"   { value = "${module.haproxy.public_ips}" }
output "haproxy_private_fqdn" { value = "${module.haproxy.private_fqdn}" }
output "haproxy_public_fqdn"  { value = "${module.haproxy.public_fqdn}" }

output "nodejs_blue_elb_zone_id"   { value = "${module.nodejs.blue_elb_zone_id}" }
output "nodejs_blue_private_fqdn"  { value = "${module.nodejs.blue_private_fqdn}" }
output "nodejs_blue_elb_dns"       { value = "${module.nodejs.blue_elb_dns}" }
output "nodejs_green_elb_zone_id"  { value = "${module.nodejs.green_elb_zone_id}" }
output "nodejs_green_private_fqdn" { value = "${module.nodejs.green_private_fqdn}" }
output "nodejs_green_elb_dns"      { value = "${module.nodejs.green_elb_dns}" }
