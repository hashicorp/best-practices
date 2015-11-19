#--------------------------------------------------------------
# General
#--------------------------------------------------------------

# When using the GitHub integration, variables are not updated
# when checked into the repository, only when you update them
# via the web interface. When making variable changes, you should
# still check them into GitHub, but don't forget to update them
# in the web UI of the appropriate environment as well.

# If you change the atlas_environment name, be sure this name
# change is reflected when doing `terraform remote config` and
# `terraform push` commands - changing this WILL affect your
# terraform.tfstate file, so use caution

name              = "staging"
artifact_type     = "amazon.image"
region            = "us-east-1"
sub_domain        = "us-east-1.aws.staging"
atlas_environment = "aws-us-east-1-staging"
atlas_aws_global  = "aws-global"
atlas_token       = "REPLACE_IN_ATLAS"
atlas_username    = "REPLACE_IN_ATLAS"
site_public_key   = "REPLACE_IN_ATLAS"
site_private_key  = "REPLACE_IN_ATLAS"
site_ssl_cert     = "REPLACE_IN_ATLAS"
site_ssl_key      = "REPLACE_IN_ATLAS"
vault_ssl_cert    = "REPLACE_IN_ATLAS"
vault_ssl_key     = "REPLACE_IN_ATLAS"
vault_token       = "REPLACE_IN_ATLAS" # No need to update until Vault is configured

#--------------------------------------------------------------
# Network
#--------------------------------------------------------------

vpc_cidr          = "10.139.0.0/16"
private_subnets   = "10.139.1.0/24,10.139.2.0/24,10.139.3.0/24"
ephemeral_subnets = "10.139.11.0/24,10.139.12.0/24,10.139.13.0/24"
public_subnets    = "10.139.101.0/24,10.139.102.0/24,10.139.103.0/24"

# Some subnets may only be able to be created in specific
# availability zones depending on your AWS account
azs = "us-east-1a,us-east-1c,us-east-1e"

# Bastion
bastion_instance_type = "t2.micro"

# NAT
nat_instance_type = "t2.micro"

# OpenVPN - https://docs.openvpn.net/how-to-tutorialsguides/virtual-platforms/amazon-ec2-appliance-ami-quick-start-guide/
openvpn_instance_type = "t2.micro"
openvpn_ami           = "ami-5fe36434"
openvpn_admin_user    = "vpnadmin"
openvpn_admin_pw      = "sdEKxN2dwDK4FziU6QEKjUeegcC8ZfBYA3fzMgqXfocgQvWGRw"
openvpn_cidr          = "172.27.139.0/24"

#--------------------------------------------------------------
# Data
#--------------------------------------------------------------

# Consul
consul_ips            = "10.139.1.4,10.139.2.4,10.139.3.4"
consul_instance_type  = "t2.small"
consul_latest_name    = "aws-us-east-1-ubuntu-consul"
consul_pinned_name    = "aws-us-east-1-ubuntu-consul"
consul_pinned_version = "latest"

# Vault
vault_nodes           = "2"
vault_instance_type   = "t2.micro"
vault_latest_name     = "aws-us-east-1-ubuntu-vault"
vault_pinned_name     = "aws-us-east-1-ubuntu-vault"
vault_pinned_version  = "latest"

#--------------------------------------------------------------
# Compute
#--------------------------------------------------------------

haproxy_instance_type  = "t2.micro"
haproxy_nodes          = "1"
haproxy_latest_name    = "aws-us-east-1-ubuntu-haproxy"
haproxy_pinned_name    = "aws-us-east-1-ubuntu-haproxy"
haproxy_pinned_version = "latest"

nodejs_instance_type  = "t2.micro"
nodejs_nodes          = "2"
nodejs_latest_name    = "aws-us-east-1-ubuntu-nodejs"
nodejs_pinned_name    = "aws-us-east-1-ubuntu-nodejs"
nodejs_pinned_version = "latest"
