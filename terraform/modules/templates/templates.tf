output "ubuntu_consul_server_user_data" { value = "${path.module}/consul_server.sh.tpl" }
output "ubuntu_consul_client_user_data" { value = "${path.module}/consul_client.sh.tpl" }
output "ubuntu_nodejs_user_data"        { value = "${path.module}/nodejs.sh.tpl" }
output "ubuntu_vault_user_data"         { value = "${path.module}/vault.sh.tpl" }
