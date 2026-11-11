# Development values. No secrets and no account identifiers.
client      = "fnc"
project     = "aroma"
environment = "dev"
region      = "us-east-1"

vpc_cidr           = "10.50.0.0/16"
availability_zones = ["us-east-1a"]

# Billed items stay off. Turn them on for a session that needs them.
enable_center_link       = false
linked_centers           = []
enable_private_endpoints = false

# Holds no real data, so a destroy may remove it.
force_destroy_data = true

# Days a destroyed key stays recoverable before AWS deletes it.
key_deletion_window_in_days = 7

common_tags = {
  Client      = "fnc"
  Project     = "aroma"
  Environment = "dev"
  Owner       = "platform"
  CostCenter  = "plataforma"
  ManagedBy   = "Terraform"
}

departments = ["cauca", "huila", "tolima"]

sample_farm = {
  farm_id    = "farm-dev-0001"
  department = "cauca"
  node_id    = "node-dev-00001"
}
