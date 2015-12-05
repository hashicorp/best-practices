#--------------------------------------------------------------
# This module creates all resources necessary for NAT
#--------------------------------------------------------------

variable "name"              { default = "nat" }
variable "vpc_id"            { }
variable "vpc_cidr"          { }
variable "region"            { }
variable "public_subnets"    { }
variable "public_subnet_ids" { }
variable "key_name"          { }
variable "private_key"       { }
variable "instance_type"     { }
variable "bastion_host"      { }
variable "bastion_user"      { }

resource "aws_security_group" "nat" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "NAT security group"

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "template_file" "nat" {
  template = "${path.module}/nat.conf.tpl"

  lifecycle { create_before_destroy = true }

  vars {
    vpc_cidr = "${var.vpc_cidr}"
  }
}

module "ami" {
  source        = "github.com/terraform-community-modules/tf_aws_ubuntu_ami/ebs"
  instance_type = "${var.instance_type}"
  region        = "${var.region}"
  distribution  = "trusty"
}

resource "aws_instance" "nat" {
  # count         = "${length(split(",", var.public_subnets))}" # Comment out count to only have 1 NAT
  ami           = "${module.ami.ami_id}"
  instance_type = "${var.instance_type}"
  subnet_id     = "${element(split(",", var.public_subnet_ids), count.index)}"
  key_name      = "${var.key_name}"
  user_data     = "${template_file.nat.rendered}"

  source_dest_check      = false
  vpc_security_group_ids = ["${aws_security_group.nat.id}"]

  tags      { Name = "${var.name}.${count.index+1}" }
  lifecycle { create_before_destroy = true }

  # Because other resources that depend on NAT need it actually
  # configured and working, we stall until `cloud-init` completes.
  provisioner "remote-exec" {
    inline = ["while sudo pkill -0 cloud-init 2>/dev/null; do sleep 2; done"]

    connection {
      user         = "ubuntu"
      host         = "${self.private_ip}"
      private_key  = "${var.private_key}"
      bastion_host = "${var.bastion_host}"
      bastion_user = "${var.bastion_user}"
    }
  }
}

output "instance_ids" { value = "${join(",", aws_instance.nat.*.id)}" }
output "private_ips"  { value = "${join(",", aws_instance.nat.*.private_ip)}" }
output "public_ips"   { value = "${join(",", aws_instance.nat.*.public_ip)}" }
