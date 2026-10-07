terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # every resource gets these tags, so it's obvious in the console what Terraform owns
  default_tags {
    tags = {
      Project   = "devops-homework"
      Session   = "18"
      ManagedBy = "Terraform"
      Owner     = var.owner
    }
  }
}
