variable "name" { default = "iam" }
variable "users" {}
variable "policy" {}

resource "aws_iam_group" "mod" {
  name = "${var.name}"
}

resource "aws_iam_group_policy" "mod" {
  name   = "${var.name}"
  group  = "${aws_iam_group.mod.id}"
  policy = "${var.policy}"
}

resource "aws_iam_user" "mod" {
  count = "${length(split(",", var.users))}"
  name  = "${var.name}-${element(split(",", var.users), count.index)}"
}

resource "aws_iam_access_key" "mod" {
  count = "${length(split(",", var.users))}"
  user  = "${element(aws_iam_user.mod.*.name, count.index)}"
}

resource "aws_iam_group_membership" "mod" {
  name  = "${var.name}"
  group = "${aws_iam_group.mod.name}"
  users = ["${aws_iam_user.mod.*.name}"]
}

output "users"       { value = "${join(",", aws_iam_access_key.mod.*.user)}" }
output "access_ids"  { value = "${join(",", aws_iam_access_key.mod.*.id)}" }
output "secret_keys" { value = "${join(",", aws_iam_access_key.mod.*.secret)}" }
