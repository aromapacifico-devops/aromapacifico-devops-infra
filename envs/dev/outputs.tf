# Outputs of the environment.
output "vpc_id" {
  description = "ID of the environment VPC."
  value       = module.network.vpc_id
}

output "subnet_ids" {
  description = "IDs of the subnets, keyed by purpose and zone."
  value       = module.network.subnet_ids
}

output "route_table_ids" {
  description = "IDs of the route tables, keyed private and private_center."
  value       = module.network.route_table_ids
}

output "iot_data_endpoint" {
  description = "MQTT endpoint the nodes connect to."
  value       = data.aws_iot_endpoint.data.endpoint_address
}

output "topic_filter" {
  description = "Topic filter of this environment."
  value       = module.telemetry_ingestion.topic_filter
}

output "push_application_arn" {
  description = "Push platform application, whose credential the operator loads outside Terraform."
  value       = module.telemetry_ingestion.push_application_arn
}

output "sample_thing_name" {
  description = "Thing of the sample farm node."
  value       = module.farm.thing_name
}

output "sample_certificate_pem" {
  description = "Public certificate of the sample farm node."
  value       = module.farm.certificate_pem
}
