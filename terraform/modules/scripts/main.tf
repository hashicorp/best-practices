output "ubuntu_consul_server_user_data" { value = "${path.module}/ubuntu/consul_server.sh" }
output "ubuntu_consul_client_user_data" { value = "${path.module}/ubuntu/consul_client.sh" }
output "ubuntu_nodejs_user_data"        { value = "${path.module}/ubuntu/nodejs.sh" }
output "ubuntu_vault_user_data"         { value = "${path.module}/ubuntu/vault.sh" }
