# Modules of the environment, each consumed by exact tag.
module "network" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-network.git?ref=v0.1.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment
}

module "security" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-security.git?ref=v0.1.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment
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
