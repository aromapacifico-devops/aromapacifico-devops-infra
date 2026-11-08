# Terraform and provider versions of the production root. The lock file pins the exact provider build.
terraform {
  required_version = ">= 1.17.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72.0"
    }
  }
}
