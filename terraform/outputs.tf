output "vpc_public_subnets" {
  description = "VPC public subnets"
  value       = local.vpc_public_subnets
}

output "security_group_id" {
  description = "Hulahoop server SG ID"
  value       = aws_security_group.hulahoop_jump_server.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "instance_profile" {
  description = "Hulahoop server IAM instance profile"
  value       = aws_iam_instance_profile.hulahoop_jump_server.name
}
