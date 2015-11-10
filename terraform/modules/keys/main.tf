variable "name" {}
variable "key_name" {}
variable "public_key" {}

resource "aws_key_pair" "key" {
  key_name   = "${var.name}"
  public_key = "${var.public_key}"

  lifecycle { create_before_destroy = true }
}

output "pem_path" { value = "${path.module}/${var.key_name}.pem" }
output "pub_path" { value = "${path.module}/${var.key_name}.pub" }
output "key_name" { value = "${aws_key_pair.key.key_name}" }
