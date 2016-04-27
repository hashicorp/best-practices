#--------------------------------------------------------------
# This module is used to achieve a blue/green deploy strategy
#--------------------------------------------------------------

variable "name"                { default = "deploy" }
variable "network"              { }
variable "key_name"            { }
variable "zone"                 { }
variable "public_subnet"       { }
variable "blue_elb_id"         { }
variable "blue_ami"            { }
variable "blue_nodes"          { }
variable "blue_instance_type"  { }
variable "blue_user_data"      { }
variable "green_elb_id"        { }
variable "green_ami"           { }
variable "green_nodes"         { }
variable "green_instance_type" { }
variable "green_user_data"     { }

resource "google_compute_firewall" "deploy" {
  name        = "${var.name}"
  network     = "${var.network}"
  description = "Firewall rule for ${var.name} Blue/Green deploy Launch Configuration"

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }

  allow {
    protocol    = "icmp"
    //TODO Add target and source tags
  }
}

resource "aws_launch_configuration" "blue" {
  name_prefix     = "${var.name}.blue."
  image_id        = "${var.blue_ami}"
  instance_type   = "${var.blue_instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.deploy.id}"]
  user_data       = "${var.blue_user_data}"

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "blue" {
  name                  = "${aws_launch_configuration.blue.name}"
  launch_configuration  = "${aws_launch_configuration.blue.name}"
  desired_capacity      = "${var.blue_nodes}"
  min_size              = "${var.blue_nodes}"
  max_size              = "${var.blue_nodes}"
  wait_for_elb_capacity = "${var.blue_nodes}"
  availability_zones    = ["${split(",", var.azs)}"]
  vpc_zone_identifier   = ["${split(",", var.private_subnet_ids)}"]
  load_balancers        = ["${var.blue_elb_id}"]

  lifecycle { create_before_destroy = true }

  tag {
    key   = "Name"
    value = "${var.name}.blue"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "green" {
  name_prefix     = "${var.name}.green."
  image_id        = "${var.green_ami}"
  instance_type   = "${var.green_instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.deploy.id}"]
  user_data       = "${var.green_user_data}"

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "green" {
  name                  = "${aws_launch_configuration.green.name}"
  launch_configuration  = "${aws_launch_configuration.green.name}"
  desired_capacity      = "${var.green_nodes}"
  min_size              = "${var.green_nodes}"
  max_size              = "${var.green_nodes}"
  wait_for_elb_capacity = "${var.green_nodes}"
  availability_zones    = ["${split(",", var.azs)}"]
  vpc_zone_identifier   = ["${split(",", var.private_subnet_ids)}"]
  load_balancers        = ["${var.green_elb_id}"]

  lifecycle { create_before_destroy = true }

  tag {
    key   = "Name"
    value = "${var.name}.green"
    propagate_at_launch = true
  }
}
