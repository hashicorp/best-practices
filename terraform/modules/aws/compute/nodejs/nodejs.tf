#--------------------------------------------------------------
# This module creates all resources necessary for the
# Node.js application
#--------------------------------------------------------------

variable "name"                { default = "nodejs" }
variable "region"              { }
variable "vpc_id"              { }
variable "vpc_cidr"            { }
variable "key_name"            { }
variable "azs"                 { }
variable "private_subnet_ids"  { }
variable "public_subnet_ids"   { }
variable "site_ssl_cert"       { }
variable "site_ssl_key"        { }
variable "vault_ssl_cert"      { }
variable "atlas_username"      { }
variable "atlas_environment"   { }
variable "atlas_aws_global"    { }
variable "atlas_token"         { }
variable "blue_ami"            { }
variable "blue_nodes"          { }
variable "blue_instance_type"  { }
variable "blue_weight"         { }
variable "green_ami"           { }
variable "green_nodes"         { }
variable "green_instance_type" { }
variable "green_weight"        { }
variable "sub_domain"          { }
variable "route_zone_id"       { }
variable "vault_token"         { default = "" }
variable "vault_policy"        { default = "nodejs" }

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

resource "aws_elb" "blue" {
  name                        = "${var.name}-blue"
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

resource "aws_elb" "green" {
  name                        = "${var.name}-green"
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

  lifecycle { create_before_destroy = true }
}

resource "template_file" "blue_user_data" {
  template = "${path.module}/nodejs.sh.tpl"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}"
    deploy            = "blue"
    site_ssl_cert     = "${var.site_ssl_cert}"
    vault_ssl_cert    = "${var.vault_ssl_cert}"
    vault_token       = "${var.vault_token}"
    vault_policy      = "${var.vault_policy}"
    aws_region        = "${var.region}"
    aws_access_id     = "${element(split(",", terraform_remote_state.aws_global.output.iam_vault_access_ids), index(split(",", terraform_remote_state.aws_global.output.iam_vault_users), format("vault-%s", var.atlas_environment)))}"
    aws_secret_key    = "${element(split(",", terraform_remote_state.aws_global.output.iam_vault_secret_keys), index(split(",", terraform_remote_state.aws_global.output.iam_vault_users), format("vault-%s", var.atlas_environment)))}"
  }
}

resource "template_file" "green_user_data" {
  template = "${path.module}/nodejs.sh.tpl"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username    = "${var.atlas_username}"
    atlas_environment = "${var.atlas_environment}"
    atlas_token       = "${var.atlas_token}"
    node_name         = "${var.name}"
    deploy            = "green"
    site_ssl_cert     = "${var.site_ssl_cert}"
    vault_ssl_cert    = "${var.vault_ssl_cert}"
    vault_token       = "${var.vault_token}"
    vault_policy      = "${var.vault_policy}"
    aws_region        = "${var.region}"
    aws_access_id     = "${element(split(",", terraform_remote_state.aws_global.output.iam_vault_access_ids), index(split(",", terraform_remote_state.aws_global.output.iam_vault_users), format("vault-%s", var.atlas_environment)))}"
    aws_secret_key    = "${element(split(",", terraform_remote_state.aws_global.output.iam_vault_secret_keys), index(split(",", terraform_remote_state.aws_global.output.iam_vault_users), format("vault-%s", var.atlas_environment)))}"
  }
}

module "deploy" {
  source = "../../util/deploy"

  name                = "${var.name}"
  vpc_id              = "${var.vpc_id}"
  vpc_cidr            = "${var.vpc_cidr}"
  key_name            = "${var.key_name}"
  azs                 = "${var.azs}"
  private_subnet_ids  = "${var.private_subnet_ids}"
  blue_elb_id         = "${aws_elb.blue.id}"
  blue_ami            = "${var.blue_ami}"
  blue_nodes          = "${var.blue_nodes}"
  blue_instance_type  = "${var.blue_instance_type}"
  blue_user_data      = "${template_file.blue_user_data.rendered}"
  green_elb_id        = "${aws_elb.green.id}"
  green_ami           = "${var.green_ami}"
  green_nodes         = "${var.green_nodes}"
  green_instance_type = "${var.green_instance_type}"
  green_user_data     = "${template_file.green_user_data.rendered}"
}

resource "aws_route53_record" "blue" {
  zone_id        = "${var.route_zone_id}"
  name           = "nodejs.${var.sub_domain}"
  type           = "A"
  weight         = "${var.blue_weight}"
  set_identifier = "blue"

  alias {
    name                   = "${aws_elb.blue.dns_name}"
    zone_id                = "${aws_elb.blue.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "green" {
  zone_id        = "${var.route_zone_id}"
  name           = "nodejs.${var.sub_domain}"
  type           = "A"
  weight         = "${var.green_weight}"
  set_identifier = "green"

  alias {
    name                   = "${aws_elb.green.dns_name}"
    zone_id                = "${aws_elb.green.zone_id}"
    evaluate_target_health = true
  }
}

output "blue_elb_zone_id"   { value = "${aws_elb.blue.zone_id}" }
output "blue_private_fqdn"  { value = "${aws_route53_record.blue.fqdn}" }
output "blue_elb_dns"       { value = "${aws_elb.blue.dns_name}" }
output "green_elb_zone_id"  { value = "${aws_elb.green.zone_id}" }
output "green_private_fqdn" { value = "${aws_route53_record.green.fqdn}" }
output "green_elb_dns"      { value = "${aws_elb.green.dns_name}" }
