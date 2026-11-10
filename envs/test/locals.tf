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
    readings_table     = "${local.name_prefix}-ddb-readings"
    ranges_table       = "${local.name_prefix}-ddb-ranges"
    alerts_table       = "${local.name_prefix}-ddb-alerts"
    alert_topic        = "${local.name_prefix}-sns-alerts"
    archive_stream     = "${local.name_prefix}-fh-archive"
    archive_bucket     = "${local.name_prefix}-s3-archive"
    ingestion_function = "${local.name_prefix}-fn-ingest"
    telemetry_rule     = "${replace(local.name_prefix, "-", "_")}_rule_telemetry"
    objects_bucket     = "${local.name_prefix}-s3-flights"
    cases_table        = "${local.name_prefix}-ddb-cases"
    focus_function     = "${local.name_prefix}-fn-focus"
    focus_dead_letter  = "${local.name_prefix}-sqs-focus-dlq"
  }

  focus_object_prefix      = "focus/"
  restricted_object_prefix = "restricted/"

  # Nova 2 Lite through the US cross-Region inference profile, which routes to these Regions.
  focus_model_id      = "us.amazon.nova-2-lite-v1:0"
  focus_model_regions = ["us-east-1", "us-east-2", "us-west-2"]

  security_keys = {
    data = {
      alias                   = "alias/${local.name_prefix}-kms-data"
      description             = "Data key of the ${var.environment} tables, queues and topics"
      deletion_window_in_days = var.key_deletion_window_in_days
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
      write_table_arns = [for table in [local.names.readings_table, local.names.alerts_table] : "arn:${local.partition}:dynamodb:${local.arn_scope}:table/${table}"]
      read_table_arns  = ["arn:${local.partition}:dynamodb:${local.arn_scope}:table/${local.names.ranges_table}"]
      topic_arns       = ["arn:${local.partition}:sns:${local.arn_scope}:${local.names.alert_topic}"]
      log_group_arns   = ["arn:${local.partition}:logs:${local.arn_scope}:log-group:/aws/lambda/${local.names.ingestion_function}"]
    }
    iot_rule = {
      name        = "${local.name_prefix}-role-iotrule"
      queue_arns  = ["arn:${local.partition}:sqs:${local.arn_scope}:${local.names.ingestion_queue}"]
      stream_arns = ["arn:${local.partition}:firehose:${local.arn_scope}:deliverystream/${local.names.archive_stream}"]
      source_arn  = "arn:${local.partition}:iot:${local.arn_scope}:rule/${local.names.telemetry_rule}"
    }
    firehose_delivery = {
      name        = "${local.name_prefix}-role-firehose"
      bucket_arns = ["arn:${local.partition}:s3:::${local.names.archive_bucket}"]
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
  }
}
