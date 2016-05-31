#--------------------------------------------------------------
# This module creates all networking resources
#--------------------------------------------------------------

variable "name"              { }
variable "zone"              { }
variable "region"            { default = "us-central1" }
variable "private_subnets"   { }
variable "public_subnets"    { }
variable "ssl_cert"          { }
variable "ssl_key"           { }
variable "sub_domain"        { }

variable "bastion_machine_type"  { }
variable "openvpn_machine_type"  { }

module "network" {
  source = "./network"

  name = "${var.name}-network"
}

module "public_subnet" {
  source = "./public_subnet"

  name            = "${var.name}-public"
  network         = "${module.network.network_uri}"
  ip_cidr_range   = "${var.public_subnets}"
  region          = "${var.region}"
}

module "bastion" {
  source = "./bastion"

  name              = "${var.name}-bastion"
  network           = "${module.network.name}"
  zone              = "${var.zone}"
  public_subnet     = "${module.public_subnet.name}"
  machine_type      = "${var.bastion_machine_type}"
}

module "private_subnet" {
  source = "./private_subnet"

  name               = "${var.name}-private"
  network            = "${module.network.name}"
  ip_cidr_range      = "${var.private_subnets}"
  region             = "${var.region}"
}

# Network
output "network_name"   { value = "${module.network.name}" }
output "network_cidr"   { value = "${module.network.ipv4_range}" }


# Subnets
output "public_subnet_ids"    { value = "${module.public_subnet.subnet_ids}" }
output "private_subnet_ids"   { value = "${module.private_subnet.subnet_ids}" }

# Bastion
output "bastion_user"       { value = "${module.bastion.user}" }
output "bastion_private_ip" { value = "${module.bastion.private_ip}" }
output "bastion_public_ip"  { value = "${module.bastion.public_ip}" }
