#--------------------------------------------------------------
# This module creates all resources necessary for Vault
#--------------------------------------------------------------

variable "name"               { default = "vault" }
variable "region"             { }
variable "vpc_id"             { }
variable "vpc_cidr"           { }
variable "private_subnet_ids" { }
variable "public_subnet_ids"  { }
variable "ssl_cert"           { }
variable "ssl_key"            { }
variable "key_name"           { }
variable "atlas_username"     { }
variable "atlas_environment"  { }
variable "atlas_token"        { }
variable "amis"               { }
variable "nodes"              { }
variable "instance_type"      { }
variable "sub_domain"         { }
variable "route_zone_id"      { }

resource "aws_security_group" "vault" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Vault"

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

resource "template_file" "user_data" {
  count    = "${var.nodes}"
  template = "${path.module}/vault.sh.tpl"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}-${count.index+1}"
    ssl_cert          = "${var.ssl_cert}"
    ssl_key           = "${var.ssl_key}"
  }
}

resource "aws_instance" "vault" {
  count         = "${var.nodes}"
  ami           = "${element(split(",", var.amis), count.index)}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(split(",", var.private_subnet_ids), count.index)}"
  user_data     = "${element(template_file.user_data.*.rendered, count.index)}"

  vpc_security_group_ids = ["${aws_security_group.vault.id}"]

  tags { Name = "${var.name}.${count.index+1}" }
}

resource "aws_security_group" "elb" {
  name   = "${var.name}-elb"
  vpc_id = "${var.vpc_id}"
  description = "Security group for Vault ELB"

  tags { Name = "${var.name}-elb" }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_server_certificate" "vault" {
  name             = "${var.region}-${var.name}"
  certificate_body = "${var.ssl_cert}"
  private_key      = "${var.ssl_key}"

  provisioner "local-exec" {
    command = <<EOF
      echo "Sleep 10 secends so that the cert is propagated by aws iam service"
      echo "See https://github.com/hashicorp/terraform/issues/2499 (terraform ~v0.6.1)"
      sleep 10
EOF
  }
}

resource "aws_elb" "vault" {
  name                        = "${var.name}"
  connection_draining         = true
  connection_draining_timeout = 400
  internal                    = true

  subnets         = ["${split(",", var.public_subnet_ids)}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.vault.*.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "tcp"
    instance_port     = 8200
    instance_protocol = "tcp"
  }

  listener {
    lb_port            = 443
    lb_protocol        = "tcp"
    instance_port      = 8200
    instance_protocol  = "tcp"
    # ssl_certificate_id = "${aws_iam_server_certificate.vault.arn}" # There's a bug with certificates right now
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    target              = "HTTPS:8200/v1/sys/health"
  }
}

resource "aws_route53_record" "vault" {
  zone_id = "${var.route_zone_id}"
  name    = "vault.${var.sub_domain}"
  type    = "CNAME"
  ttl     = "5"
  records = ["${aws_elb.vault.dns_name}"]
}

output "private_ips"  { value = "${join(",", aws_instance.vault.*.private_ip)}" }
output "elb_dns"      { value = "${aws_elb.vault.dns_name}" }
output "private_fqdn" { value = "${aws_route53_record.vault.fqdn}" }
