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
