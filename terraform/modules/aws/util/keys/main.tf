#--------------------------------------------------------------
# This module is used to create AWS key pairs
#--------------------------------------------------------------

variable "name"       { }
variable "public_key" { }

resource "aws_key_pair" "key" {
  key_name   = "${var.name}"
  public_key = "${var.public_key}"

  lifecycle { create_before_destroy = true }
}

output "key_name" { value = "${aws_key_pair.key.key_name}" }
