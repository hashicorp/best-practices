#--------------------------------------------------------------
# This module creates all resources necessary for NAT
#--------------------------------------------------------------

variable "name"              { default = "nat" }
variable "public_subnet_ids" { }

resource "aws_eip" "nat" {
  # count = "${length(split(",", var.public_subnet_ids))}" # Comment out count to only have 1 NAT
  vpc   = true

  lifecycle { create_before_destroy = true }
}

resource "aws_nat_gateway" "nat" {
  # count         = "${length(split(",", var.public_subnet_ids))}" # Comment out count to only have 1 NAT
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
  subnet_id     = "${element(split(",", var.public_subnet_ids), count.index)}"

  lifecycle { create_before_destroy = true }
}

output "gateway_ids" { value = "${join(",", aws_nat_gateway.nat.*.id)}" }
