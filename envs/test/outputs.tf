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

output "vpn_gateway_id" {
  description = "ID of the virtual private gateway, or null when no center is linked."
  value       = module.network.vpn_gateway_id
}

output "center_link_connection_ids" {
  description = "VPN connection of each linked center, keyed by department code."
  value       = module.network.center_link_connection_ids
}

output "center_link_tunnel_addresses" {
  description = "Outside addresses of the two tunnels of each linked center, for the firewall of the center."
  value       = module.network.center_link_tunnel_addresses
}

output "center_link_secret_arns" {
  description = "Secret that holds the pre-shared keys of each linked center. It is a name. The installer reads the keys from Secrets Manager and they are never an output."
  value       = module.network.center_link_secret_arns
}

output "center_link_routes" {
  description = "Ranges routed toward each linked center."
  value       = module.network.center_link_routes
}

output "platform_event_bus_name" {
  description = "Bus where the mission link publishes flight records."
  value       = module.inference_function.event_bus_name
}

output "focus_work_queue_arn" {
  description = "Work queue of the focus confirmation function."
  value       = module.inference_function.work_queue_arn
}

output "focus_dead_letter_queue_arn" {
  description = "Dead letter queue of the focus confirmation function."
  value       = module.inference_function.dead_letter_queue_arn
}
