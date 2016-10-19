template {
  source = "/opt/consul_template/haproxy.ctmpl"
  destination = "/etc/haproxy/haproxy.cfg"
  command = "service haproxy restart"
}
