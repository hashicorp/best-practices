variable "name" {}
variable "admins" {}
variable "account_id" {}

# Admin IAM
resource "aws_iam_group" "admins" {
  name = "${var.name}-admins"
}

resource "aws_iam_group_policy" "admins" {
  name   = "${var.name}-admins"
  group  = "${aws_iam_group.admins.id}"
  policy = <<EOF
{
  "Version"  : "2012-10-17",
  "Statement": [
    {
      "Effect"  : "Allow",
      "Action"  : "*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_user" "admins" {
  count = "${length(split(",", var.admins))}"
  name  = "${var.name}-${element(split(",", var.admins), count.index)}"
}

resource "aws_iam_access_key" "admins" {
  count = "${length(split(",", var.admins))}"
  user  = "${element(aws_iam_user.admins.*.name, count.index)}"
}

resource "aws_iam_group_membership" "admins" {
  name  = "${var.name}-admins"
  group = "${aws_iam_group.admins.name}"
  users = ["${aws_iam_user.admins.*.name}"]
}

# Vault IAM
resource "aws_iam_group" "vault" {
  name = "${var.name}-vault"
}

resource "aws_iam_group_policy" "vault" {
  name   = "${var.name}-vault"
  group  = "${aws_iam_group.vault.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateAccessKey",
        "iam:CreateUser",
        "iam:PutUserPolicy",
        "iam:ListGroupsForUser",
        "iam:ListUserPolicies",
        "iam:ListAccessKeys",
        "iam:DeleteAccessKey",
        "iam:DeleteUserPolicy",
        "iam:RemoveUserFromGroup",
        "iam:DeleteUser"
      ],
      "Resource": [
        "arn:aws:iam::${replace(var.account_id, "-", "")}:user/vault-*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_user" "vault" {
  name = "root"
}

resource "aws_iam_access_key" "vault" {
  user = "${aws_iam_user.vault.name}"
}

resource "aws_iam_group_membership" "vault" {
  name  = "${var.name}-vault"
  group = "${aws_iam_group.vault.name}"
  users = ["${aws_iam_user.vault.name}"]
}

# Admins
output "admin_users"       { value = "${join(",", aws_iam_access_key.admins.*.user)}" }
output "admin_access_ids"  { value = "${join(",", aws_iam_access_key.admins.*.id)}" }
output "admin_secret_keys" { value = "${join(",", aws_iam_access_key.admins.*.secret)}" }

# Vault
output "vault_user"       { value = "${aws_iam_access_key.vault.user}" }
output "vault_access_id"  { value = "${aws_iam_access_key.vault.id}" }
output "vault_secret_key" { value = "${aws_iam_access_key.vault.secret}" }
