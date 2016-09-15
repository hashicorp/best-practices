name = "prod"

project = "REPLACE_IN_ATLAS"

region = "us-central1"

zones = ["us-central1-a", "us-central1-b", "us-central1-c"]

credentials = "REPLACE_IN_ATLAS"

atlas_username = "REPLACE_IN_ATLAS"

atlas_environment = "google-us-central1-prod"

atlas_token = "REPLACE_IN_ATLAS"

ssh_keys = "REPLACE_IN_ATLAS"

cidr = "10.139.0.0/16"

private_subnets = ["10.139.1.0/24", "10.139.2.0/24", "10.139.3.0/24"]

public_subnets = ["10.139.101.0/24", "10.139.102.0/24", "10.139.103.0/24"]

consul_artifact_name = "google-ubuntu-consul"

consul_node_count = "3"

consul_instance_type = "n1-standard-1"

vault_artifact_name = "google-ubuntu-vault"

vault_node_count = "2"

vault_instance_type = "n1-standard-1"

vault_ssl_cert = "REPLACE_IN_ATLAS"

vault_ssl_key = "REPLACE_IN_ATLAS"

vault_token = "REPLACE_IN_ATLAS" # No need to update until Vault is configured

haproxy_artifact_name = "google-ubuntu-haproxy"

haproxy_node_count = "1"

haproxy_instance_type = "n1-standard-1"

nodejs_artifact_name = "google-ubuntu-nodejs"

nodejs_node_count = "1"

nodejs_instance_type = "n1-standard-1"

site_ssl_cert = "REPLACE_IN_ATLAS"
site_ssl_key = "REPLACE_IN_ATLAS"

bastion_image = "ubuntu-1404-trusty-v20160114e"
bastion_instance_type = "n1-standard-1"

