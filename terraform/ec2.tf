resource "aws_security_group" "hulahoop_jump_server" {
  name        = "hulahoop_jump_server"
  description = "SG for hulahoop jump server"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "allow_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.hulahoop_jump_server.id
}
