# Configuration payloads for the modules, with final resource names, are built here.
locals {
  name_prefix = "${var.client}-${var.project}-${var.environment}"

  vpc_name = "${local.name_prefix}-vpc-main"

  # Each purpose takes a /20 block in this order, and each zone inside it takes a /24.
  subnet_purposes = ["telemetry-ingress", "drone-ingress", "application", "data", "object-storage", "administration", "public-query"]

  subnets = merge([
    for purpose_index, purpose in local.subnet_purposes : {
      for zone_index, zone in var.availability_zones :
      "${purpose}-${substr(zone, -1, 1)}" => {
        name              = "${local.name_prefix}-subnet-${purpose}-${substr(zone, -1, 1)}"
        purpose           = purpose
        cidr              = cidrsubnet(var.vpc_cidr, 8, purpose_index * 16 + zone_index)
        availability_zone = zone
      }
    }
  ]...)

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  partition  = data.aws_partition.current.partition
  arn_scope  = "${local.region}:${local.account_id}"

  # Final names of the workload resources. The ingestion and function modules receive them, and the
  # security module builds role permissions from their ARNs. IoT rule names accept no hyphens.
  names = {
    ingestion_queue    = "${local.name_prefix}-sqs-ingest"
    ingestion_dlq      = "${local.name_prefix}-sqs-ingest-dlq"
    delivery_dlq       = "${local.name_prefix}-sqs-dlvcheck-dlq"
    iot_policy         = "${local.name_prefix}-iotpol-node"
    readings_table     = "${local.name_prefix}-ddb-readings"
    ranges_table       = "${local.name_prefix}-ddb-ranges"
    alerts_table       = "${local.name_prefix}-ddb-alerts"
    farms_table        = "${local.name_prefix}-ddb-farms"
    delivery_queue     = "${local.name_prefix}-sqs-dlvcheck"
    push_application   = "${local.name_prefix}-push-fcm"
    sms_config_set     = "${local.name_prefix}-sms-alerts"
    archive_database   = "${replace(local.name_prefix, "-", "_")}_telemetry"
    archive_table      = "readings"
    status_function    = "${local.name_prefix}-fn-dlvstatus"
    check_function     = "${local.name_prefix}-fn-dlvcheck"
    sms_status_logs    = "/aws/sms/${local.name_prefix}-status"
    archive_stream     = "${local.name_prefix}-fh-archive"
    archive_bucket     = "${local.name_prefix}-s3-archive"
    ingestion_function = "${local.name_prefix}-fn-ingest"
    telemetry_rule     = "${replace(local.name_prefix, "-", "_")}_rule_telemetry"
    objects_bucket     = "${local.name_prefix}-s3-flights"
    cases_table        = "${local.name_prefix}-ddb-cases"
    focus_function     = "${local.name_prefix}-fn-focus"
    focus_dead_letter  = "${local.name_prefix}-sqs-focus-dlq"
  }

  table_arn = "arn:${local.partition}:dynamodb:${local.arn_scope}:table"
  queue_arn = "arn:${local.partition}:sqs:${local.arn_scope}"
  logs_arn  = "arn:${local.partition}:logs:${local.arn_scope}:log-group"

  # SNS names the status log groups of a platform application after the application.
  push_application_path = "app/GCM/${local.names.push_application}"
  sms_config_set_arn    = "arn:${local.partition}:sms-voice:${local.arn_scope}:configuration-set/${local.names.sms_config_set}"

  focus_object_prefix      = "focus/"
  restricted_object_prefix = "restricted/"

  # Nova 2 Lite through the US cross-Region inference profile, which routes to these Regions.
  focus_model_id      = "us.amazon.nova-2-lite-v1:0"
  focus_model_regions = ["us-east-1", "us-east-2", "us-west-2"]

  security_keys = {
    data = {
      alias                   = "alias/${local.name_prefix}-kms-data"
      description             = "Data key of the ${var.environment} tables, queues and log groups"
      deletion_window_in_days = var.key_deletion_window_in_days
      service_principals      = ["logs.${local.region}.amazonaws.com"]
    }
    objects = {
      alias                   = "alias/${local.name_prefix}-kms-objects"
      description             = "Objects key of the ${var.environment} buckets"
      deletion_window_in_days = var.key_deletion_window_in_days
    }
  }

  security_roles = {
    ingestion_function = {
      name             = "${local.name_prefix}-role-ingest"
      queue_arns       = ["arn:${local.partition}:sqs:${local.arn_scope}:${local.names.ingestion_queue}"]
      write_table_arns = [for table in [local.names.readings_table, local.names.alerts_table] : "${local.table_arn}/${table}"]
      read_table_arns  = [for table in [local.names.ranges_table, local.names.farms_table] : "${local.table_arn}/${table}"]
      log_group_arns   = ["${local.logs_arn}:/aws/lambda/${local.names.ingestion_function}"]

      push_application_arns = ["arn:${local.partition}:sns:${local.arn_scope}:${local.push_application_path}"]
      send_queue_arns       = ["${local.queue_arn}:${local.names.delivery_queue}"]
    }
    iot_rule = {
      name        = "${local.name_prefix}-role-iotrule"
      queue_arns  = ["arn:${local.partition}:sqs:${local.arn_scope}:${local.names.ingestion_queue}"]
      stream_arns = ["arn:${local.partition}:firehose:${local.arn_scope}:deliverystream/${local.names.archive_stream}"]
      source_arn  = "arn:${local.partition}:iot:${local.arn_scope}:rule/${local.names.telemetry_rule}"
    }
    firehose_delivery = {
      name            = "${local.name_prefix}-role-firehose"
      bucket_arns     = ["arn:${local.partition}:s3:::${local.names.archive_bucket}"]
      glue_table_arns = ["arn:${local.partition}:glue:${local.arn_scope}:table/${local.names.archive_database}/${local.names.archive_table}"]
    }
    focus_function = {
      name              = "${local.name_prefix}-role-focus"
      bucket_arns       = ["arn:${local.partition}:s3:::${local.names.objects_bucket}"]
      object_prefix     = local.focus_object_prefix
      restricted_prefix = local.restricted_object_prefix
      model_arns = concat(
        ["arn:${local.partition}:bedrock:${local.arn_scope}:inference-profile/${local.focus_model_id}"],
        [for region in local.focus_model_regions : "arn:${local.partition}:bedrock:${region}::foundation-model/${trimprefix(local.focus_model_id, "us.")}"]
      )
      write_table_arns       = ["arn:${local.partition}:dynamodb:${local.arn_scope}:table/${local.names.cases_table}"]
      dead_letter_queue_arns = ["arn:${local.partition}:sqs:${local.arn_scope}:${local.names.focus_dead_letter}"]
      log_group_arns         = ["arn:${local.partition}:logs:${local.arn_scope}:log-group:/aws/lambda/${local.names.focus_function}"]
    }
    delivery_status_function = {
      name             = "${local.name_prefix}-role-dlvstat"
      write_table_arns = ["${local.table_arn}/${local.names.alerts_table}"]
      log_group_arns   = ["${local.logs_arn}:/aws/lambda/${local.names.status_function}"]
    }
    delivery_check_function = {
      name              = "${local.name_prefix}-role-dlvcheck"
      queue_arns        = ["${local.queue_arn}:${local.names.delivery_queue}"]
      write_table_arns  = ["${local.table_arn}/${local.names.alerts_table}"]
      read_table_arns   = ["${local.table_arn}/${local.names.farms_table}"]
      sms_resource_arns = [local.sms_config_set_arn]
      log_group_arns    = ["${local.logs_arn}:/aws/lambda/${local.names.check_function}"]
    }
    push_status_logs = {
      name = "${local.name_prefix}-role-pushlogs"
      log_group_arns = [
        "${local.logs_arn}:sns/${local.region}/${local.account_id}/${local.push_application_path}",
        "${local.logs_arn}:sns/${local.region}/${local.account_id}/${local.push_application_path}/Failure",
      ]
    }
    sms_status_logs = {
      name           = "${local.name_prefix}-role-smslogs"
      log_group_arns = ["${local.logs_arn}:${local.names.sms_status_logs}"]
      source_arn     = local.sms_config_set_arn
    }
  }

  # Names the telemetry ingestion module receives.
  ingestion_names = {
    ingestion_queue             = local.names.ingestion_queue
    ingestion_dead_letter_queue = local.names.ingestion_dlq
    delivery_queue              = local.names.delivery_queue
    delivery_dead_letter_queue  = local.names.delivery_dlq
    readings_table              = local.names.readings_table
    ranges_table                = local.names.ranges_table
    alerts_table                = local.names.alerts_table
    farms_table                 = local.names.farms_table
    archive_bucket              = local.names.archive_bucket
    archive_stream              = local.names.archive_stream
    archive_database            = local.names.archive_database
    archive_table               = local.names.archive_table
    telemetry_rule              = local.names.telemetry_rule
    iot_policy                  = local.names.iot_policy
    ingestion_function          = local.names.ingestion_function
    status_function             = local.names.status_function
    check_function              = local.names.check_function
    push_application            = local.names.push_application
    sms_config_set              = local.names.sms_config_set
    sms_status_logs             = local.names.sms_status_logs
  }

  thing_groups = { for department in var.departments : department => "${local.name_prefix}-thg-${department}" }

  # The ingestion function stores readings. Alert logic belongs to the platform application, so the
  # delivery functions run a placeholder that only logs.
  function_packages = {
    ingestion       = { path = data.archive_file.functions["ingestion"].output_path }
    delivery_status = { path = data.archive_file.functions["placeholder"].output_path }
    delivery_check  = { path = data.archive_file.functions["placeholder"].output_path }
  }

  # Initial ranges of the pilot, written once as version 1. Later versions come from the platform API.
  ranges_valid_from = "2026-11-10T00:00:00Z"

  alert_ranges = [
    {
      zone_type   = "cultivation"
      variable    = "ph"
      unit        = "pH"
      valid_from  = local.ranges_valid_from
      reason      = "Initial range of the pilot"
      alert       = { min = 4.5, max = 6.0 }
      recommended = { min = 4.9, max = 5.6 }
    },
    {
      zone_type  = "cultivation"
      variable   = "soil_humidity_pct"
      unit       = "percent"
      valid_from = local.ranges_valid_from
      reason     = "Initial range of the pilot, bound to soil humidity"
      alert      = { min = 40, max = 80 }
    },
    {
      zone_type   = "cultivation"
      variable    = "air_temp_c"
      unit        = "°C"
      valid_from  = local.ranges_valid_from
      reason      = "Initial range of the pilot, bound to air temperature"
      alert       = { min = 14, max = 30 }
      recommended = { min = 17, max = 23 }
    },
    {
      zone_type  = "drying"
      variable   = "grain_temp_c"
      unit       = "°C"
      valid_from = local.ranges_valid_from
      reason     = "Initial range of the pilot, grain above 40 °C"
      alert      = { max = 40, max_included = false }
    },
    {
      zone_type  = "drying"
      variable   = "grain_humidity_pct"
      unit       = "percent"
      valid_from = local.ranges_valid_from
      reason     = "Initial reference of the pilot"
      reference  = { target = 12 }
    },
  ]
}

# Inputs of the cloud firewall rules in the security module.
locals {
  # Logistics range 10.X.3.0/24 and local server range 10.X.10.0/24 of each linked center, in a fixed order.
  center_cidrs = flatten([for octet in sort([for center in var.linked_centers : tostring(center)]) : ["10.${octet}.3.0/24", "10.${octet}.10.0/24"]])

  # Subnets that receive traffic from the centers. The rest stay closed.
  open_subnet_purposes = ["telemetry-ingress", "drone-ingress", "application"]

  open_subnet_ids   = [for key, subnet in local.subnets : module.network.subnet_ids[key] if contains(local.open_subnet_purposes, subnet.purpose)]
  closed_subnet_ids = [for key, subnet in local.subnets : module.network.subnet_ids[key] if !contains(local.open_subnet_purposes, subnet.purpose)]
}

# Collection centers to link. Empty while enable_center_link is false, so no VPN resource is planned.
locals {
  center_names = { "41" = "cauca", "42" = "huila", "43" = "tolima" }

  center_links = var.enable_center_link ? {
    for center in var.linked_centers : tostring(center) => {
      name      = local.center_names[tostring(center)]
      public_ip = var.center_link_ips[tostring(center)]
    }
  } : {}
}
