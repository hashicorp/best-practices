#--------------------------------------------------------------
# This module creates all resources necessary for the
# Node.js application
#--------------------------------------------------------------

variable "name"               { default = "nodejs" }
variable "region"             { }
variable "vpc_id"             { }
variable "vpc_cidr"           { }
variable "key_name"           { }
variable "azs"                { }
variable "private_subnet_ids" { }
variable "public_subnet_ids"  { }
variable "site_ssl_cert"      { }
variable "site_ssl_key"       { }
variable "vault_ssl_cert"     { }
variable "atlas_username"     { }
variable "atlas_environment"  { }
variable "atlas_aws_global"   { }
variable "atlas_token"        { }
variable "ami"                { }
variable "nodes"              { }
variable "instance_type"      { }
variable "user_data"          { }
variable "sub_domain"         { }
variable "route_zone_id"      { }
variable "vault_token"        { default = "" }
variable "vault_policy"       { default = "nodejs" }

resource "aws_security_group" "elb" {
  name        = "${var.name}.elb"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Nodejs ELB"

  tags      { Name = "${var.name}-elb" }
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

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_server_certificate" "nodejs" {
  name             = "${var.region}-${var.name}"
  certificate_body = "${var.site_ssl_cert}"
  private_key      = "${var.site_ssl_key}"

  lifecycle { create_before_destroy = true }

  provisioner "local-exec" {
    command = <<EOF
      echo "Sleep 10 secends so that the cert is propagated by aws iam service"
      echo "See https://github.com/hashicorp/terraform/issues/2499 (terraform ~v0.6.1)"
      sleep 10
EOF
  }
}

resource "aws_elb" "nodejs" {
  name                        = "${var.name}"
  connection_draining         = true
  connection_draining_timeout = 400

  subnets         = ["${split(",", var.public_subnet_ids)}"]
  security_groups = ["${aws_security_group.elb.id}"]

  lifecycle { create_before_destroy = true }

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 8888
    instance_protocol = "http"
  }

  listener {
    lb_port            = 443
    lb_protocol        = "https"
    instance_port      = 8888
    instance_protocol  = "http"
    ssl_certificate_id = "${aws_iam_server_certificate.nodejs.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 15
    target              = "HTTP:8888/"
  }
}

resource "terraform_remote_state" "aws_global" {
  backend = "atlas"

  config {
    name = "${var.atlas_username}/${var.atlas_aws_global}"
  }
}

resource "template_file" "user_data" {
  template = "${var.user_data}"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}"
    site_ssl_cert     = "${var.site_ssl_cert}"
    vault_ssl_cert    = "${var.vault_ssl_cert}"
    vault_token       = "${var.vault_token}"
    vault_policy      = "${var.vault_policy}"
    aws_region        = "${var.region}"
    aws_access_id     = "${element(split(",", terraform_remote_state.aws_global.output.iam_vault_access_ids), index(split(",", terraform_remote_state.aws_global.output.iam_vault_users), format("vault-%s", var.atlas_environment)))}"
    aws_secret_key    = "${element(split(",", terraform_remote_state.aws_global.output.iam_vault_secret_keys), index(split(",", terraform_remote_state.aws_global.output.iam_vault_users), format("vault-%s", var.atlas_environment)))}"
  }
}

module "rolling" {
  source = "../../util/rolling"

  name               = "${var.name}"
  vpc_id             = "${var.vpc_id}"
  vpc_cidr           = "${var.vpc_cidr}"
  key_name           = "${var.key_name}"
  azs                = "${var.azs}"
  private_subnet_ids = "${var.private_subnet_ids}"
  elb_id             = "${aws_elb.nodejs.id}"
  ami                = "${var.ami}"
  nodes              = "${var.nodes}"
  instance_type      = "${var.instance_type}"
  user_data          = "${template_file.user_data.rendered}"
}

resource "aws_route53_record" "nodejs" {
  zone_id = "${var.route_zone_id}"
  name    = "nodejs.${var.sub_domain}"
  type    = "A"

  alias {
    name                   = "${aws_elb.nodejs.dns_name}"
    zone_id                = "${aws_elb.nodejs.zone_id}"
    evaluate_target_health = true
  }
}

output "zone_id"      { value = "${aws_elb.nodejs.zone_id}" }
output "elb_dns"      { value = "${aws_elb.nodejs.dns_name}" }
output "private_fqdn" { value = "${aws_route53_record.nodejs.fqdn}" }
