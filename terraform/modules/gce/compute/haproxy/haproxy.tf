#--------------------------------------------------------------
# This module creates all resources necessary for HAProxy
#--------------------------------------------------------------

variable "name"              { default = "haproxy" }
variable "vpc_id"            { }
variable "vpc_cidr"          { }
variable "key_name"          { }
variable "subnet_ids"        { }
variable "atlas_username"    { }
variable "atlas_environment" { }
variable "atlas_token"       { }
variable "amis"              { }
variable "nodes"             { }
variable "instance_type"     { }
variable "sub_domain"        { }
variable "route_zone_id"     { }

resource "aws_security_group" "haproxy" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "HAProxy security group"

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

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
  template = "${path.module}/haproxy.sh.tpl"
  count    = "${var.nodes}"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}-${count.index+1}"
  }
}

resource "aws_instance" "haproxy" {
  ami           = "${element(split(",", var.amis), count.index)}"
  count         = "${var.nodes}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(split(",", var.subnet_ids), count.index)}"
  user_data     = "${element(template_file.user_data.*.rendered, count.index)}"

  vpc_security_group_ids = ["${aws_security_group.haproxy.id}"]

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "haproxy_public" {
  zone_id = "${var.route_zone_id}"
  name    = "haproxy.${var.sub_domain}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.haproxy.*.public_ip}"]
}

resource "aws_route53_record" "haproxy_private" {
  zone_id = "${var.route_zone_id}"
  name    = "private.haproxy.${var.sub_domain}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.haproxy.*.private_ip}"]
}

output "public_ips"   { value = "${join(",", aws_instance.haproxy.*.public_ip)}" }
output "private_ips"  { value = "${join(",", aws_instance.haproxy.*.private_ip)}" }
output "public_fqdn"  { value = "${aws_route53_record.haproxy_public.fqdn}" }
output "private_fqdn" { value = "${aws_route53_record.haproxy_private.fqdn}" }
