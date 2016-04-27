#--------------------------------------------------------------
# This module creates all resources necessary for Consul
#--------------------------------------------------------------

variable "name"               { default = "consul" }
variable "network"            { }
variable "zone"               { default = "us-central1-c" }
variable "public_subnet"      { }
variable "key_name"           { }
variable "atlas_username"     { }
variable "atlas_environment"  { }
variable "atlas_token"        { }
variable "image"              { default = "ubuntu-1404-trusty-v20160406" }
variable "nodes"              { }
variable "machine_type"       { default = "n1-standard-1" }
variable "openvpn_user"       { }
variable "openvpn_host"       { }
variable "private_key"        { }
variable "bastion_host"       { }
variable "bastion_user"       { }

resource "google_compute_firewall" "consul" {
  name        = "${var.name}"
  network      = "${var.network}"
  description = "Firewall rule for Consul"

  tags      { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }

  allow {
    protocol    = "icmp"
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

resource "google_compute_instance" "consul" {
  count                   = "${var.nodes}"
  machine_type            = "${var.machine_type}"
  zone                    = "${var.zone}"
  key_name                = "${var.key_name}"
  metadata_startup_script = "${element(template_file.user_data.*.rendered, count.index)}"

  tags { Name = "${var.name}.${count.index+1}" }

  disk {
    image = "${var.image}"
  }

  network_interface {
    subnetwork = "${module.public_subnet.name}"
    access_config {
    }
  }

}

resource "null_resource" "openvpn_dns" {
  triggers {
    consul_private_ips = "${join(",", google_compute_instance.consul.*.network_interface.*.access_config.assigned_nat_ip)}"
    openvpn_host       = "${var.openvpn_host}"
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

output "private_ips" { value = "${join(",", google_compute_instance.haproxy.*.network_interface.*.access_config.assigned_nat_ip)}" }
