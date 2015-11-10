variable "name" { default = "consul" }
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "private_subnet_ids" {}
variable "key_name" {}
variable "atlas_username" {}
variable "atlas_environment" {}
variable "atlas_token" {}
variable "user_data" {}
variable "instance_type" {}
variable "static_ips" {}
variable "amis" {}

resource "aws_security_group" "consul" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Consul"

  tags { Name = "${var.name}" }

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

resource "template_file" "user_data" {
  count    = "${length(split(",", var.static_ips))}"
  filename = "${var.user_data}"

  vars {
    atlas_username      = "${var.atlas_username}"
    atlas_environment   = "${var.atlas_environment}"
    atlas_token         = "${var.atlas_token}"
    consul_server_count = "${length(split(",", var.static_ips))}"
    node_name           = "${var.name}-${count.index+1}"
  }
}

resource "aws_instance" "consul" {
  count         = "${length(split(",", var.static_ips))}"
  ami           = "${element(split(",", var.amis), count.index)}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  private_ip    = "${element(split(",", var.static_ips), count.index)}"
  subnet_id     = "${element(split(",", var.private_subnet_ids), count.index)}"
  user_data     = "${element(template_file.user_data.*.rendered, count.index)}"

  vpc_security_group_ids = ["${aws_security_group.consul.id}"]

  tags { Name = "${var.name}.${count.index+1}" }
}

output "private_ips" { value = "${join(",", aws_instance.consul.*.private_ip)}" }
