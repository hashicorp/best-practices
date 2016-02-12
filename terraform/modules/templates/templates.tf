output "consul_user_data"  { value = "${path.module}/consul.sh.tpl" }
output "vault_user_data"   { value = "${path.module}/vault.sh.tpl" }
output "haproxy_user_data" { value = "${path.module}/haproxy.sh.tpl" }
output "nodejs_user_data"  { value = "${path.module}/nodejs.sh.tpl" }
