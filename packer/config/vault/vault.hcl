backend "consul" {
  path = "vault"
  address = "127.0.0.1:8500"
  advertise_addr = "https://{{ node_name }}.node.consul:8200"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "{{ tls_cert_file }}"
  tls_key_file = "{{ tls_key_file }}"
}
