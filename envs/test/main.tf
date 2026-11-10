# Modules of the environment, each consumed by exact tag.
module "network" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-network.git?ref=v1.0.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  vpc_name                 = local.vpc_name
  vpc_cidr                 = var.vpc_cidr
  subnets                  = local.subnets
  enable_private_endpoints = var.enable_private_endpoints

  # The security module provides these groups. Until it does, a plan with private endpoints on stops at the module validation.
  endpoint_security_group_ids = {}
}

module "security" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-security.git?ref=v0.3.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  keys  = local.security_keys
  roles = local.security_roles
}

module "telemetry_ingestion" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-telemetry-ingestion.git?ref=v0.1.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment
}

module "inference_function" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-inference-function.git?ref=v0.1.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment
}

module "farm" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-farm.git?ref=v0.1.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment
}
