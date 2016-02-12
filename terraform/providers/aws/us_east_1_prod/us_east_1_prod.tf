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

variable "openvpn_instance_type" { }
variable "openvpn_ami"           { }
variable "openvpn_user"          { }
variable "openvpn_admin_user"    { }
variable "openvpn_admin_pw"      { }
variable "openvpn_cidr"          { }

variable "consul_node_count"    { }
variable "consul_instance_type" { }
variable "consul_artifact_name" { }
variable "consul_artifacts"     { }

variable "vault_node_count"    { }
variable "vault_instance_type" { }
variable "vault_artifact_name" { }
variable "vault_artifacts"     { }

variable "haproxy_node_count"    { }
variable "haproxy_instance_type" { }
variable "haproxy_artifact_name" { }
variable "haproxy_artifacts"     { }

variable "nodejs_blue_node_count"     { }
variable "nodejs_blue_instance_type"  { }
variable "nodejs_blue_weight"         { }
variable "nodejs_green_node_count"    { }
variable "nodejs_green_instance_type" { }
variable "nodejs_green_weight"        { }
variable "nodejs_artifact_name"       { }
variable "nodejs_artifacts"           { }

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

  lifecycle { create_before_destroy = true }
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
  openvpn_instance_type = "${var.openvpn_instance_type}"
  openvpn_ami           = "${var.openvpn_ami}"
  openvpn_user          = "${var.openvpn_user}"
  openvpn_admin_user    = "${var.openvpn_admin_user}"
  openvpn_admin_pw      = "${var.openvpn_admin_pw}"
  openvpn_cidr          = "${var.openvpn_cidr}"
}

module "artifact_consul" {
  source = "../../../modules/aws/util/artifact"

  type             = "${var.artifact_type}"
  region           = "${var.region}"
  atlas_username   = "${var.atlas_username}"
  artifact_name    = "${var.consul_artifact_name}"
  artifact_version = "${var.consul_artifacts}"
}

module "artifact_vault" {
  source = "../../../modules/aws/util/artifact"

  type             = "${var.artifact_type}"
  region           = "${var.region}"
  atlas_username   = "${var.atlas_username}"
  artifact_name    = "${var.vault_artifact_name}"
  artifact_version = "${var.vault_artifacts}"
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

  consul_amis          = "${module.artifact_consul.amis}"
  consul_node_count    = "${var.consul_node_count}"
  consul_instance_type = "${var.consul_instance_type}"
  openvpn_user         = "${var.openvpn_user}"
  openvpn_host         = "${module.network.openvpn_private_ip}"
  private_key          = "${var.site_private_key}"
  bastion_host         = "${module.network.bastion_public_ip}"
  bastion_user         = "${module.network.bastion_user}"

  vault_amis          = "${module.artifact_vault.amis}"
  vault_node_count    = "${var.vault_node_count}"
  vault_instance_type = "${var.vault_instance_type}"
}

module "artifact_haproxy" {
  source = "../../../modules/aws/util/artifact"

  type             = "${var.artifact_type}"
  region           = "${var.region}"
  atlas_username   = "${var.atlas_username}"
  artifact_name    = "${var.haproxy_artifact_name}"
  artifact_version = "${var.haproxy_artifacts}"
}

module "artifact_nodejs" {
  source = "../../../modules/aws/util/artifact"

  type             = "${var.artifact_type}"
  region           = "${var.region}"
  atlas_username   = "${var.atlas_username}"
  artifact_name    = "${var.nodejs_artifact_name}"
  artifact_version = "${var.nodejs_artifacts}"
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

  haproxy_amis          = "${module.artifact_haproxy.amis}"
  haproxy_node_count    = "${var.haproxy_node_count}"
  haproxy_instance_type = "${var.haproxy_instance_type}"

  nodejs_blue_ami            = "${element(split(",", module.artifact_nodejs.amis), 0)}"
  nodejs_blue_node_count     = "${var.nodejs_blue_node_count}"
  nodejs_blue_instance_type  = "${var.nodejs_blue_instance_type}"
  nodejs_blue_weight         = "${var.nodejs_blue_weight}"
  nodejs_green_ami           = "${element(split(",", module.artifact_nodejs.amis), 1)}"
  nodejs_green_node_count    = "${var.nodejs_green_node_count}"
  nodejs_green_instance_type = "${var.nodejs_green_instance_type}"
  nodejs_green_weight        = "${var.nodejs_green_weight}"
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
  Node.js (blue): ${module.compute.nodejs_blue_private_fqdn}
                  ${module.compute.nodejs_blue_elb_dns}

  Node.js (green): ${module.compute.nodejs_green_private_fqdn}
                   ${module.compute.nodejs_green_elb_dns}

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
CONFIGURATION
}
