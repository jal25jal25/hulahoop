variable "aws_region" {
  description = "AWS Resource Region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project Name"
  type        = string
  default     = "Hulahoop"
}

variable "vpc_cidr" {
  description = "VPC Cidr Block"
  type        = string
  default     = "172.31.0.0/16"
}

variable "vpc_az_count" {
  description = "Number of AZs to use in region"
  type        = number
  default     = 2
}
