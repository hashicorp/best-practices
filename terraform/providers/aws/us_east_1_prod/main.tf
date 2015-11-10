variable "region" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_aws_global" {}
variable "atlas_token" {}
variable "artifact_type" {}
variable "name" {}
variable "site_ssl_cert" {}
variable "site_ssl_key" {}
variable "vault_ssl_cert" {}
variable "vault_ssl_key" {}
variable "site_key_name" {}
variable "site_public_key" {}
variable "site_private_key" {}
variable "vpc_cidr" {}
variable "public_subnets" {}
variable "private_subnets" {}
variable "ephemeral_subnets" {}
variable "azs" {}
variable "sub_domain" {}
variable "vault_token" { default = "" }

variable "bastion_instance_type" {}
variable "nat_instance_type" {}

variable "openvpn_instance_type" {}
variable "openvpn_ami" {}
variable "openvpn_admin_user" {}
variable "openvpn_admin_pw" {}
variable "openvpn_cidr" {}

variable "consul_ips" {}
variable "consul_instance_type" {}
variable "consul_latest_name" {}
variable "consul_pinned_name" {}
variable "consul_pinned_version" {}

variable "vault_nodes" {}
variable "vault_instance_type" {}
variable "vault_latest_name" {}
variable "vault_pinned_name" {}
variable "vault_pinned_version" {}

variable "haproxy_instance_type" {}
variable "haproxy_nodes" {}
variable "haproxy_latest_name" {}
variable "haproxy_pinned_name" {}
variable "haproxy_pinned_version" {}
variable "haproxy_sub_domain" {}

variable "nodejs_instance_type" {}
variable "nodejs_nodes" {}
variable "nodejs_latest_name" {}
variable "nodejs_pinned_name" {}
variable "nodejs_pinned_version" {}

# Provider
provider "aws" {
  region = "${var.region}"
}

atlas {
  name = "${var.atlas_username}/${var.atlas_environment}"
}

resource "terraform_remote_state" "aws_global" {
  backend = "atlas"

  config {
    name = "${var.atlas_username}/${var.atlas_aws_global}"
  }
}

# Access
module "site_key" {
  source = "../../../modules/keys"

  name       = "${var.name}"
  key_name   = "${var.site_key_name}"
  public_key = "${var.site_public_key}"
}

module "scripts" {
  source = "../../../modules/scripts"
}

# Network
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
  key_name          = "${module.site_key.key_name}"
  key_file          = "${module.site_key.pem_path}"
  # key_file          = "${var.site_private_key}" # Use this once Terraform supports it
  domain            = "${terraform_remote_state.aws_global.output.prod_fqdn}"
  sub_domain        = "${var.sub_domain}"
  route_zone_id     = "${terraform_remote_state.aws_global.output.zone_id}"

  bastion_instance_type = "${var.bastion_instance_type}"
  nat_instance_type     = "${var.nat_instance_type}"
  openvpn_instance_type = "${var.openvpn_instance_type}"
  openvpn_ami           = "${var.openvpn_ami}"
  openvpn_admin_user    = "${var.openvpn_admin_user}"
  openvpn_admin_pw      = "${var.openvpn_admin_pw}"
  openvpn_dns_ips       = "${var.consul_ips}"
  openvpn_cidr          = "${var.openvpn_cidr}"
}

# Data
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
  key_name           = "${module.site_key.key_name}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  domain             = "${terraform_remote_state.aws_global.output.prod_fqdn}"
  sub_domain         = "${var.sub_domain}"
  route_zone_id      = "${terraform_remote_state.aws_global.output.zone_id}"

  consul_user_data     = "${module.scripts.ubuntu_consul_server_user_data}"
  consul_instance_type = "${var.consul_instance_type}"
  consul_ips           = "${var.consul_ips}"
  consul_amis          = "${module.artifact_consul.latest},${module.artifact_consul.latest},${module.artifact_consul.latest}"

  vault_user_data     = "${module.scripts.ubuntu_vault_user_data}"
  vault_instance_type = "${var.vault_instance_type}"
  vault_nodes         = "${var.vault_nodes}"
  vault_amis          = "${module.artifact_vault.latest},${module.artifact_vault.latest}"
}

# Compute
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
  key_name           = "${module.site_key.key_name}"
  azs                = "${var.azs}"
  private_subnet_ids = "${module.network.private_subnet_ids}"
  public_subnet_ids  = "${module.network.public_subnet_ids}"
  site_ssl_cert      = "${var.site_ssl_cert}"
  site_ssl_key       = "${var.site_ssl_key}"
  vault_ssl_cert     = "${var.vault_ssl_cert}"
  atlas_username     = "${var.atlas_username}"
  atlas_environment  = "${var.atlas_environment}"
  atlas_token        = "${var.atlas_token}"
  domain             = "${terraform_remote_state.aws_global.output.prod_fqdn}"
  sub_domain         = "${var.sub_domain}"
  route_zone_id      = "${terraform_remote_state.aws_global.output.zone_id}"
  vault_token        = "${var.vault_token}"

  haproxy_user_data     = "${module.scripts.ubuntu_consul_client_user_data}"
  haproxy_nodes         = "${var.haproxy_nodes}"
  haproxy_amis          = "${module.artifact_haproxy.latest}"
  haproxy_instance_type = "${var.haproxy_instance_type}"
  haproxy_sub_domain    = "${var.haproxy_sub_domain}"

  nodejs_user_data     = "${module.scripts.ubuntu_nodejs_user_data}"
  nodejs_nodes         = "${var.nodejs_nodes}"
  nodejs_ami           = "${module.artifact_nodejs.latest}"
  nodejs_instance_type = "${var.nodejs_instance_type}"
}

module "website" {
  source = "../../../modules/aws/util/website"

  fqdn          = "${var.sub_domain}.${terraform_remote_state.aws_global.output.prod_fqdn}"
  domain        = "${terraform_remote_state.aws_global.output.prod_fqdn}"
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
           ${replace(formatlist("http://%s/\n           ", split(",", module.compute.haproxy_public_ips)), "B780FFEC-B661-4EB8-9236-A01737AD98B6", "")}
Add your private key and SSH into any private node via the Bastion host:
  ssh-add ../../../modules/keys/demo.pem
  ssh -A ${module.network.bastion_user}@${module.network.bastion_public_ip}

Private node IPs:
  Consul: ${replace(formatlist("ssh ubuntu@%s\n          ", split(",", module.data.consul_private_ips)), "B780FFEC-B661-4EB8-9236-A01737AD98B6", "")}
  Vault: ${replace(formatlist("ssh ubuntu@%s\n         ", split(",", module.data.vault_private_ips)), "B780FFEC-B661-4EB8-9236-A01737AD98B6", "")}
  HAProxy: ${replace(formatlist("ssh ubuntu@%s\n           ", split(",", module.compute.haproxy_private_ips)), "B780FFEC-B661-4EB8-9236-A01737AD98B6", "")}
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
  ${replace(formatlist("http://%s:8500/ui/\n  ", split(",", module.data.consul_private_ips)), "B780FFEC-B661-4EB8-9236-A01737AD98B6", "")}
Visit the HAProxy stats page:
  http://${module.compute.haproxy_private_fqdn}:1936/haproxy?stats
  ${replace(formatlist("http://%s:1936/haproxy?stats\n  ", split(",", module.compute.haproxy_private_ips)), "B780FFEC-B661-4EB8-9236-A01737AD98B6", "")}
Interact with Vault:
  Vault: ${module.data.vault_private_fqdn}
CONFIGURATION
}
