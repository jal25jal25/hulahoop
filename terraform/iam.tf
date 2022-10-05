### Protected server

resource "aws_iam_policy" "hulahoop_protected_server" {
  name        = "hulahoop_protected_server"
  path        = "/"
  description = "Hulahoop policy to be attached to user for protected server"
  policy      = "${file("policies/hulahoop_protected_server.json")}"
}

resource "aws_iam_user" "hulahoop_protected_server" {
  name = "hulahoop_protected_server"
}

resource "aws_iam_user_policy_attachment" "hulahoop_protected_server" {
  user       = aws_iam_user.hulahoop_protected_server.name
  policy_arn = aws_iam_policy.hulahoop_protected_server.arn
}

### Public hulahoop server

resource "aws_iam_policy" "hulahoop_jump_server" {
  name        = "hulahoop_jump_server"
  path        = "/"
  description = "Hulahoop policy to be attached to role for hulahoop jump server"
  policy      = "${data.template_file.hulahoop_jump_server_policy.rendered}"
}

resource "aws_iam_role" "hulahoop_jump_server" {
  name = "hulahoop_jump_server"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "hulahoop_jump_server" {
  role       = aws_iam_role.hulahoop_jump_server.name
  policy_arn = aws_iam_policy.hulahoop_jump_server.arn
}

resource "aws_iam_instance_profile" "hulahoop_jump_server" {
  name = "hulahoop_jump_server"
  role = aws_iam_role.hulahoop_jump_server.name
}

data "template_file" "hulahoop_jump_server_policy" {
  template = "${file("policies/hulahoop_jump_server.tpl")}"

  vars = {
    region = var.aws_region
    account_id = data.aws_caller_identity.current.account_id
    security_group_id = aws_security_group.hulahoop_jump_server.id
  }
}

### Caller

resource "aws_iam_policy" "hulahoop_caller" {
  name        = "hulahoop_caller"
  path        = "/"
  description = "Hulahoop policy to be attached to user for calling party" 
  policy      = "${data.template_file.hulahoop_caller_policy.rendered}"
}

resource "aws_iam_user" "hulahoop_caller" {
  name = "hulahoop_caller"
}

resource "aws_iam_user_policy_attachment" "hulahoop_caller" {
  user       = aws_iam_user.hulahoop_caller.name
  policy_arn = aws_iam_policy.hulahoop_caller.arn
}

data "template_file" "hulahoop_caller_policy" {
  template = "${file("policies/hulahoop_caller.tpl")}"

  vars = {
    region = var.aws_region
    account_id = data.aws_caller_identity.current.account_id
    instance_role = aws_iam_role.hulahoop_jump_server.name
    security_group_id = aws_security_group.hulahoop_jump_server.id
  }
}

