variable "name"              { }
variable "artifact_type"     { }
variable "region"            { }
variable "sub_domain"        { }
variable "atlas_environment" { }
variable "atlas_aws_global"  { }
variable "atlas_token"       { }
variable "atlas_username"    { }
variable "site_public_key"   { }
variable "site_private_key"  { }
variable "site_ssl_cert"     { }
variable "site_ssl_key"      { }
variable "vault_ssl_cert"    { }
variable "vault_ssl_key"     { }
variable "vault_token"       { default = "" }

variable "vpc_cidr"          { }
variable "azs"               { }
variable "private_subnets"   { }
variable "ephemeral_subnets" { }
variable "public_subnets"    { }

variable "bastion_instance_type" { }
variable "nat_instance_type"     { }

variable "openvpn_instance_type" { }
variable "openvpn_ami"           { }
variable "openvpn_user"          { }
variable "openvpn_admin_user"    { }
variable "openvpn_admin_pw"      { }
variable "openvpn_cidr"          { }

variable "consul_node_count"     { }
variable "consul_instance_type"  { }
variable "consul_latest_name"    { }
variable "consul_pinned_name"    { }
variable "consul_pinned_version" { }

variable "vault_node_count"     { }
variable "vault_instance_type"  { }
variable "vault_latest_name"    { }
variable "vault_pinned_name"    { }
variable "vault_pinned_version" { }

variable "haproxy_node_count"     { }
variable "haproxy_instance_type"  { }
variable "haproxy_latest_name"    { }
variable "haproxy_pinned_name"    { }
variable "haproxy_pinned_version" { }

variable "nodejs_node_count"     { }
variable "nodejs_instance_type"  { }
variable "nodejs_latest_name"    { }
variable "nodejs_pinned_name"    { }
variable "nodejs_pinned_version" { }

provider "aws" {
  region = "${var.region}"
}

atlas {
  name = "${var.atlas_username}/${var.atlas_environment}"
}

resource "aws_key_pair" "site_key" {
  key_name   = "${var.name}"
  public_key = "${var.site_public_key}"

  lifecycle { create_before_destroy = true }
}

resource "terraform_remote_state" "aws_global" {
  backend = "atlas"

  config {
    name = "${var.atlas_username}/${var.atlas_aws_global}"
  }
}

module "network" {
  source = "../../../modules/aws/network"

  name              = "${var.name}"
  vpc_cidr          = "${var.vpc_cidr}"
  azs               = "${var.azs}"
  region            = "${var.region}"
  private_subnets   = "${var.private_subnets}"
  ephemeral_subnets = "${var.ephemeral_subnets}"
  public_subnets    = "${var.public_subnets}"
  ssl_cert          = "${var.site_ssl_cert}"
  ssl_key           = "${var.site_ssl_key}"
  key_name          = "${aws_key_pair.site_key.key_name}"
  private_key       = "${var.site_private_key}"
  sub_domain        = "${var.sub_domain}"
  route_zone_id     = "${terraform_remote_state.aws_global.output.zone_id}"

  bastion_instance_type = "${var.bastion_instance_type}"
  nat_instance_type     = "${var.nat_instance_type}"
  openvpn_instance_type = "${var.openvpn_instance_type}"
  openvpn_ami           = "${var.openvpn_ami}"
  openvpn_user          = "${var.openvpn_user}"
  openvpn_admin_user    = "${var.openvpn_admin_user}"
  openvpn_admin_pw      = "${var.openvpn_admin_pw}"
  openvpn_cidr          = "${var.openvpn_cidr}"
}

module "artifact_consul" {
  source = "../../../modules/aws/util/artifact"

  type           = "${var.artifact_type}"
  region         = "${var.region}"
  atlas_username = "${var.atlas_username}"
  latest_name    = "${var.consul_latest_name}"
  pinned_name    = "${var.consul_pinned_name}"
  pinned_version = "${var.consul_pinned_version}"
}

module "artifact_vault" {
  source = "../../../modules/aws/util/artifact"

  type           = "${var.artifact_type}"
  region         = "${var.region}"
  atlas_username = "${var.atlas_username}"
  latest_name    = "${var.vault_latest_name}"
  pinned_name    = "${var.vault_pinned_name}"
  pinned_version = "${var.vault_pinned_version}"
}

module "templates" {
  source = "../../../modules/templates"
}

module "data" {
  source = "../../../modules/aws/data"

  name               = "${var.name}"
  region             = "${var.region}"
  vpc_id             = "${module.network.vpc_id}"
  vpc_cidr           = "${var.vpc_cidr}"
  private_subnet_ids = "${module.network.private_subnet_ids}"
  public_subnet_ids  = "${module.network.public_subnet_ids}"
  ssl_cert           = "${var.vault_ssl_cert}"
  ssl_key            = "${var.vault_ssl_key}"
  key_name           = "${aws_key_pair.site_key.key_name}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  sub_domain         = "${var.sub_domain}"
  route_zone_id      = "${terraform_remote_state.aws_global.output.zone_id}"

  consul_amis          = "${module.artifact_consul.latest},${module.artifact_consul.latest},${module.artifact_consul.latest}"
  consul_node_count    = "${var.consul_node_count}"
  consul_instance_type = "${var.consul_instance_type}"
  consul_user_data     = "${module.templates.ubuntu_consul_server_user_data}"
  openvpn_user         = "${var.openvpn_user}"
  openvpn_host         = "${module.network.openvpn_private_ip}"
  private_key          = "${var.site_private_key}"
  bastion_host         = "${module.network.bastion_public_ip}"
  bastion_user         = "${module.network.bastion_user}"

  vault_amis          = "${module.artifact_vault.latest},${module.artifact_vault.latest}"
  vault_node_count    = "${var.vault_node_count}"
  vault_instance_type = "${var.vault_instance_type}"
  vault_user_data     = "${module.templates.ubuntu_vault_user_data}"
}

module "artifact_haproxy" {
  source = "../../../modules/aws/util/artifact"

  type           = "${var.artifact_type}"
  region         = "${var.region}"
  atlas_username = "${var.atlas_username}"
  latest_name    = "${var.haproxy_latest_name}"
  pinned_name    = "${var.haproxy_pinned_name}"
  pinned_version = "${var.haproxy_pinned_version}"
}

module "artifact_nodejs" {
  source = "../../../modules/aws/util/artifact"

  type           = "${var.artifact_type}"
  region         = "${var.region}"
  atlas_username = "${var.atlas_username}"
  latest_name    = "${var.nodejs_latest_name}"
  pinned_name    = "${var.nodejs_pinned_name}"
  pinned_version = "${var.nodejs_pinned_version}"
}

module "compute" {
  source = "../../../modules/aws/compute"

  name               = "${var.name}"
  region             = "${var.region}"
  vpc_id             = "${module.network.vpc_id}"
  vpc_cidr           = "${var.vpc_cidr}"
  key_name           = "${aws_key_pair.site_key.key_name}"
  azs                = "${var.azs}"
  private_subnet_ids = "${module.network.private_subnet_ids}"
  public_subnet_ids  = "${module.network.public_subnet_ids}"
  site_ssl_cert      = "${var.site_ssl_cert}"
  site_ssl_key       = "${var.site_ssl_key}"
  vault_ssl_cert     = "${var.vault_ssl_cert}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_aws_global   = "${var.atlas_aws_global}"
  atlas_token        = "${var.atlas_token}"
  sub_domain         = "${var.sub_domain}"
  route_zone_id      = "${terraform_remote_state.aws_global.output.zone_id}"
  vault_token        = "${var.vault_token}"

  haproxy_amis          = "${module.artifact_haproxy.latest}"
  haproxy_node_count    = "${var.haproxy_node_count}"
  haproxy_instance_type = "${var.haproxy_instance_type}"
  haproxy_user_data     = "${module.templates.ubuntu_consul_client_user_data}"

  nodejs_ami           = "${module.artifact_nodejs.latest}"
  nodejs_node_count    = "${var.nodejs_node_count}"
  nodejs_instance_type = "${var.nodejs_instance_type}"
  nodejs_user_data     = "${module.templates.ubuntu_nodejs_user_data}"
}

module "website" {
  source = "../../../modules/aws/util/website"

  fqdn          = "${var.sub_domain}.${terraform_remote_state.aws_global.output.prod_fqdn}"
  sub_domain    = "${var.sub_domain}"
  route_zone_id = "${terraform_remote_state.aws_global.output.zone_id}"
}

output "configuration" {
  value = <<CONFIGURATION

Visit the static website hosted on S3:
  Prod: ${terraform_remote_state.aws_global.output.prod_fqdn}
        ${terraform_remote_state.aws_global.output.prod_endpoint}

  Staging: ${terraform_remote_state.aws_global.output.staging_fqdn}
           ${terraform_remote_state.aws_global.output.staging_endpoint}

  Region: ${module.website.fqdn}
          ${module.website.endpoint}

Visit the Node.js website:
  Node.js: ${module.compute.nodejs_private_fqdn}
           ${module.compute.nodejs_elb_dns}

  HAProxy: ${module.compute.haproxy_public_fqdn}
           ${join("\n           ", formatlist("http://%s/", split(",", module.compute.haproxy_public_ips)))}

Add your private key and SSH into any private node via the Bastion host:
  ssh-add ../../../modules/keys/demo.pem
  ssh -A ${module.network.bastion_user}@${module.network.bastion_public_ip}

Private node IPs:
  Consul: ${join("\n          ", formatlist("ssh ubuntu@%s", split(",", module.data.consul_private_ips)))}

  Vault: ${join("\n         ", formatlist("ssh ubuntu@%s", split(",", module.data.vault_private_ips)))}

  HAProxy: ${join("\n           ", formatlist("ssh ubuntu@%s", split(",", module.compute.haproxy_private_ips)))}

The VPC environment is accessible via an OpenVPN connection:
  Server:   ${module.network.openvpn_public_fqdn}
            ${module.network.openvpn_public_ip}
  Username: ${var.openvpn_admin_user}
  Password: ${var.openvpn_admin_pw}

You can administer the OpenVPN Access Server:
  https://${module.network.openvpn_public_fqdn}/admin
  https://${module.network.openvpn_public_ip}/admin

Once you're on the VPN, you can...

Visit the Consul UI:
  http://consul.service.consul:8500/ui/

Use Consul DNS:
  ssh ubuntu@consul.service.consul
  ssh ubuntu@vault.service.consul
  ssh ubuntu@haproxy.service.consul
  ssh ubuntu@web.service.consul
  ssh ubuntu@nodejs.web.service.consul

Visit the HAProxy stats page:
  http://haproxy.service.consul:1936/haproxy?stats
  http://${module.compute.haproxy_private_fqdn}:1936/haproxy?stats
  ${join("\n  ", formatlist("http://%s:1936/haproxy?stats", split(",", module.compute.haproxy_private_ips)))}

Interact with Vault:
  Vault: ${module.data.vault_private_fqdn}
         ${module.data.vault_elb_dns}
         
Cameron's demo.
CONFIGURATION
}
