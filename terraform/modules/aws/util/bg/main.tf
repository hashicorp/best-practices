variable "name" { default = "bg" }
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "key_name" {}
variable "azs" {}
variable "private_subnet_ids" {}
variable "elb_id" {}
variable "blue_ami" {}
variable "blue_nodes" {}
variable "blue_instance_type" {}
variable "blue_user_data" {}
variable "green_ami" {}
variable "green_nodes" {}
variable "green_instance_type" {}
variable "green_user_data" {}

resource "aws_security_group" "bg" {
  vpc_id      = "${var.vpc_id}"
  description = "Security group for ${var.name} Blue/Green Launch Configuration"

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

resource "aws_launch_configuration" "blue" {
  image_id        = "${var.blue_ami}"
  instance_type   = "${var.blue_instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.bg.id}"]
  user_data       = "${var.blue_user_data}"

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "blue" {
  name                 = "${var.name}.blue.${var.blue_ami}"
  launch_configuration = "${aws_launch_configuration.blue.name}"
  desired_capacity     = "${var.blue_nodes}"
  min_size             = "${var.blue_nodes}"
  max_size             = "${var.blue_nodes}"
  min_elb_capacity     = "${var.blue_nodes}"
  availability_zones   = ["${split(",", var.azs)}"]
  vpc_zone_identifier  = ["${split(",", var.private_subnet_ids)}"]
  load_balancers       = ["${var.elb_id}"]

  lifecycle { create_before_destroy = true }

  tag {
    key   = "Name"
    value = "${var.name}.blue"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "green" {
  image_id        = "${var.green_ami}"
  instance_type   = "${var.green_instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.bg.id}"]
  user_data       = "${var.green_user_data}"

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "green" {
  name                 = "${var.name}.green.${var.green_ami}"
  launch_configuration = "${aws_launch_configuration.green.name}"
  desired_capacity     = "${var.green_nodes}"
  min_size             = "${var.green_nodes}"
  max_size             = "${var.green_nodes}"
  min_elb_capacity     = "${var.green_nodes}"
  availability_zones   = ["${split(",", var.azs)}"]
  vpc_zone_identifier  = ["${split(",", var.private_subnet_ids)}"]
  load_balancers       = ["${var.elb_id}"]

  lifecycle { create_before_destroy = true }

  tag {
    key   = "Name"
    value = "${var.name}.green"
    propagate_at_launch = true
  }
}
