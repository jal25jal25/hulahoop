locals {
  vpc_az_suffixes        = ["a", "b", "c", "d"]

  vpc_azs              = [for x in slice(local.vpc_az_suffixes, 0, var.vpc_az_count) : "${var.aws_region}${x}"]
  vpc_private_subnets  = []
  vpc_database_subnets = []
  vpc_public_subnets   = cidrsubnets(var.vpc_cidr, [for x in range(0, var.vpc_az_count) : 8]...)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v3.14.2"

  name = var.project_name

  create_vpc                             = true
  create_igw                             = true
  enable_dns_hostnames                   = true
  enable_dns_support                     = true
  enable_nat_gateway                     = false
  single_nat_gateway                     = false
  one_nat_gateway_per_az                 = false

  cidr                                   = var.vpc_cidr
  azs                                    = local.vpc_azs

  public_subnets                         = local.vpc_public_subnets
  private_subnets                        = local.vpc_private_subnets
  database_subnets                       = local.vpc_database_subnets
  create_database_subnet_route_table     = false
  create_database_subnet_group           = false
  create_database_internet_gateway_route = false
  create_database_nat_gateway_route      = false

  enable_flow_log                        = false
  create_flow_log_cloudwatch_log_group   = false
  create_flow_log_cloudwatch_iam_role    = false
  flow_log_max_aggregation_interval      = 60
}
