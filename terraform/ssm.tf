resource "aws_ssm_parameter" "hulahoop_public_keys" {
  name        = "/hulahoop/public_keys"
  description = "SSH public keys to be appended to the authorized_keys file on the hulahoop jump server"
  type        = "SecureString"
  value       = "${file("parameters/hulahoop_public_keys.txt")}"
}
