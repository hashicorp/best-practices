variable "name" { default = "asg" }
variable "vpc_id" {}
variable "vpc_cidr" {}
variable "key_name" {}
variable "azs" {}
variable "private_subnet_ids" {}
variable "elb_id" {}
variable "ami" {}
variable "nodes" {}
variable "instance_type" {}
variable "user_data" {}

resource "aws_security_group" "asg" {
  vpc_id      = "${var.vpc_id}"
  description = "Security group for ${var.name} ASG Launch Configuration"

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

resource "aws_launch_configuration" "asg" {
  image_id        = "${var.ami}"
  instance_type   = "${var.instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.asg.id}"]
  user_data       = "${var.user_data}"

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "asg" {
  name                 = "${var.name}.${var.ami}"
  launch_configuration = "${aws_launch_configuration.asg.name}"
  desired_capacity     = "${var.nodes}"
  min_size             = "${var.nodes}"
  max_size             = "${var.nodes}"
  min_elb_capacity     = "${var.nodes}"
  availability_zones   = ["${split(",", var.azs)}"]
  vpc_zone_identifier  = ["${split(",", var.private_subnet_ids)}"]
  load_balancers       = ["${var.elb_id}"]

  lifecycle { create_before_destroy = true }

  tag {
    key   = "Name"
    value = "${var.name}"
    propagate_at_launch = true
  }
}
