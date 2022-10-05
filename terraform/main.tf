terraform {
  required_version = ">= 1.1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.18"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 2.2"
    }
  }

  backend "s3" {}

}

locals {
  default_tags = {
    "Project"     = var.project_name
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.default_tags
  }
}

data "aws_caller_identity" "current" {}
