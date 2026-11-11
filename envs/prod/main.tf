# Modules of the environment, each consumed by exact tag.
module "network" {
  #checkov:skip=CKV_TF_1:Release tags cannot move or be deleted, see docs/iac-exceptions.md
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-network.git?ref=v1.1.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  # Cost center of every resource of the module, see docs/governance/tags-policies-and-budgets.md.
  additional_tags = { CostCenter = "plataforma" }

  vpc_name                 = local.vpc_name
  vpc_cidr                 = var.vpc_cidr
  subnets                  = local.subnets
  enable_private_endpoints = var.enable_private_endpoints

  endpoint_security_group_ids = module.security.endpoint_security_group_ids

  # Empty unless enable_center_link is true. Every linked center then needs its own address, see center_link_ips.
  center_links = local.center_links
}

module "security" {
  #checkov:skip=CKV_TF_1:Release tags cannot move or be deleted, see docs/iac-exceptions.md
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-security.git?ref=v0.6.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  # Cost center of every resource of the module, see docs/governance/tags-policies-and-budgets.md.
  additional_tags = { CostCenter = "seguridad" }

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
  #checkov:skip=CKV_TF_1:Release tags cannot move or be deleted, see docs/iac-exceptions.md
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-telemetry-ingestion.git?ref=v1.0.1"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  # Cost center of every resource of the module, see docs/governance/tags-policies-and-budgets.md.
  additional_tags = { CostCenter = "fincas" }

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
  #checkov:skip=CKV_TF_1:Release tags cannot move or be deleted, see docs/iac-exceptions.md
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-inference-function.git?ref=v1.0.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  # Cost center of every resource of the module, see docs/governance/tags-policies-and-budgets.md.
  additional_tags = { CostCenter = "drones" }

  data_key_arn    = module.security.data_key_arn
  objects_key_arn = module.security.objects_key_arn
  role_arns = {
    function = module.security.focus_function_role_arn
    delivery = module.security.focus_delivery_role_arn
  }

  names             = local.inference_names
  mission_type      = "FOCUS_CONFIRMATION"
  object_prefix     = local.focus_object_prefix
  restricted_prefix = local.restricted_object_prefix
  bedrock_model_id  = local.focus_model_id

  # The person filter, the model call and the result belong to the platform application, so the
  # function runs the placeholder that only logs.
  function_package   = { path = data.archive_file.functions["placeholder"].output_path }
  force_destroy_data = var.force_destroy_data
}

# One sample farm per environment, since environments share the thing registry of the account.
module "farm" {
  #checkov:skip=CKV_TF_1:Release tags cannot move or be deleted, see docs/iac-exceptions.md
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-farm.git?ref=v1.0.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  # Cost center of every resource of the module, see docs/governance/tags-policies-and-budgets.md.
  additional_tags = { CostCenter = "fincas" }

  iot_policy_name  = module.telemetry_ingestion.iot_policy_name
  thing_group_name = module.telemetry_ingestion.thing_group_names[var.sample_farm.department]

  farm_id    = var.sample_farm.farm_id
  department = var.sample_farm.department
  node_id    = var.sample_farm.node_id
  csr_pem    = file("${path.module}/sample-node.csr")
}
