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

  endpoint_security_group_ids = module.security.endpoint_security_group_ids
}

module "security" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-security.git?ref=feat/12-firewall-rules"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  keys  = local.security_keys
  roles = local.security_roles

  firewall = {
    vpc_id                 = module.network.vpc_id
    open_subnet_ids        = local.open_subnet_ids
    closed_subnet_ids      = local.closed_subnet_ids
    center_cidrs           = local.center_cidrs
    enable_endpoint_groups = var.enable_private_endpoints
  }
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
