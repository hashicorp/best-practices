#--------------------------------------------------------------
# This module creates all resources necessary for Consul
#--------------------------------------------------------------

variable "name"               { default = "consul" }
variable "vpc_id"             { }
variable "vpc_cidr"           { }
variable "private_subnet_ids" { }
variable "key_name"           { }
variable "atlas_username"     { }
variable "atlas_environment"  { }
variable "atlas_token"        { }
variable "amis"               { }
variable "nodes"              { }
variable "instance_type"      { }
variable "openvpn_user"       { }
variable "openvpn_host"       { }
variable "private_key"        { }
variable "bastion_host"       { }
variable "bastion_user"       { }

resource "aws_security_group" "consul" {
  name        = "${var.name}"
  vpc_id      = "${var.vpc_id}"
  description = "Security group for Consul"

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
  template = "${path.module}/consul.sh.tpl"

  lifecycle { create_before_destroy = true }

  vars {
    atlas_username      = "${var.atlas_username}"
    atlas_environment   = "${var.atlas_environment}"
    atlas_token         = "${var.atlas_token}"
    consul_server_count = "${var.nodes}"
    node_name           = "${var.name}-${count.index+1}"
  }
}

resource "aws_instance" "consul" {
  count         = "${var.nodes}"
  ami           = "${element(split(",", var.amis), count.index)}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${element(split(",", var.private_subnet_ids), count.index)}"
  user_data     = "${element(template_file.user_data.*.rendered, count.index)}"

  vpc_security_group_ids = ["${aws_security_group.consul.id}"]

  tags { Name = "${var.name}.${count.index+1}" }
}

resource "null_resource" "openvpn_dns" {
  triggers {
    consul_private_ips = "${join(",", aws_instance.consul.*.private_ip)}"
  }

  connection {
    user         = "${var.openvpn_user}"
    host         = "${var.openvpn_host}"
    private_key  = "${var.private_key}"
    bastion_host = "${var.bastion_host}"
    bastion_user = "${var.bastion_user}"
  }

  provisioner "remote-exec" {
    inline = [
      # Turn on custom DNS
      "sudo /usr/local/openvpn_as/scripts/sacli -k vpn.client.routing.reroute_dns -v custom ConfigPut",
      # Point custom DNS at consul
      "sudo /usr/local/openvpn_as/scripts/sacli -k vpn.server.dhcp_option.dns.0 -v ${element(aws_instance.consul.*.private_ip, 0)} ConfigPut",
      "sudo /usr/local/openvpn_as/scripts/sacli -k vpn.server.dhcp_option.dns.1 -v ${element(aws_instance.consul.*.private_ip, 1)} ConfigPut",
      # Do a warm restart so the config is picked up
      "sudo /usr/local/openvpn_as/scripts/sacli start",
    ]
  }
}

output "private_ips" { value = "${join(",", aws_instance.consul.*.private_ip)}" }
