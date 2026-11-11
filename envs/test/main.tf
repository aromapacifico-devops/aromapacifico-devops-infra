# Modules of the environment, each consumed by exact tag.
module "network" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-network.git?ref=v1.1.0"

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

  # Empty unless enable_center_link is true. Every linked center then needs its own address, see center_link_ips.
  center_links = local.center_links
}

module "security" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-security.git?ref=v0.5.0"

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
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-telemetry-ingestion.git?ref=v1.0.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  data_key_arn    = module.security.data_key_arn
  objects_key_arn = module.security.objects_key_arn
  role_arns = {
    ingestion_function       = module.security.ingestion_function_role_arn
    iot_rule                 = module.security.iot_rule_role_arn
    firehose_delivery        = module.security.firehose_role_arn
    delivery_status_function = module.security.delivery_status_function_role_arn
    delivery_check_function  = module.security.delivery_check_function_role_arn
    push_status_logs         = module.security.push_status_logs_role_arn
    sms_status_logs          = module.security.sms_status_logs_role_arn
  }

  names              = local.ingestion_names
  thing_groups       = local.thing_groups
  function_packages  = local.function_packages
  alert_ranges       = local.alert_ranges
  force_destroy_data = var.force_destroy_data
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

# One sample farm per environment, since environments share the thing registry of the account.
module "farm" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-farm.git?ref=v1.0.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  iot_policy_name  = module.telemetry_ingestion.iot_policy_name
  thing_group_name = module.telemetry_ingestion.thing_group_names[var.sample_farm.department]

  farm_id    = var.sample_farm.farm_id
  department = var.sample_farm.department
  node_id    = var.sample_farm.node_id
  csr_pem    = file("${path.module}/sample-node.csr")
}
