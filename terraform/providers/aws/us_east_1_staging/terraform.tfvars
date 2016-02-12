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
azs               = "us-east-1a,us-east-1c,us-east-1e" # AZs are region specific
private_subnets   = "10.139.1.0/24,10.139.2.0/24,10.139.3.0/24" # Creating one private subnet per AZ
ephemeral_subnets = "10.139.11.0/24,10.139.12.0/24,10.139.13.0/24" # Creating one ephemeral subnet per AZ
public_subnets    = "10.139.101.0/24,10.139.102.0/24,10.139.103.0/24" # Creating one public subnet per AZ

# Bastion
bastion_instance_type = "t2.micro"

# NAT
nat_instance_type = "t2.micro"

# OpenVPN - https://docs.openvpn.net/how-to-tutorialsguides/virtual-platforms/amazon-ec2-appliance-ami-quick-start-guide/
openvpn_instance_type = "t2.micro"
openvpn_ami           = "ami-5fe36434"
openvpn_user          = "openvpnas"
openvpn_admin_user    = "vpnadmin"
openvpn_admin_pw      = "sdEKxN2dwDK4FziU6QEKjUeegcC8ZfBYA3fzMgqXfocgQvWGRw"
openvpn_cidr          = "172.27.139.0/24"

#--------------------------------------------------------------
# Data
#--------------------------------------------------------------

# Consul
consul_node_count    = "3"
consul_instance_type = "t2.small"
consul_artifact_name = "aws-us-east-1-ubuntu-consul"
consul_artifacts     = "latest,latest,latest" # Comma separated list of artifact version numbers, list length must match node count

# Vault
vault_node_count    = "2"
vault_instance_type = "t2.micro"
vault_artifact_name = "aws-us-east-1-ubuntu-vault"
vault_artifacts     = "latest,latest" # Comma separated list of artifact version numbers, list length must match node count

#--------------------------------------------------------------
# Compute
#--------------------------------------------------------------

haproxy_node_count    = "1"
haproxy_instance_type = "t2.micro"
haproxy_artifact_name = "aws-us-east-1-ubuntu-haproxy"
haproxy_artifacts     = "latest" # Comma separated list of artifact version numbers, list length must match node count

nodejs_blue_node_count     = "2"
nodejs_blue_instance_type  = "t2.micro"
nodejs_blue_weight         = "100"
nodejs_green_node_count    = "0"
nodejs_green_instance_type = "t2.micro"
nodejs_green_weight        = "0"
nodejs_artifact_name       = "aws-us-east-1-ubuntu-nodejs"
nodejs_artifacts           = "latest,latest" # Comma separated "blue,green" artifact version numbers, list length must be 2
