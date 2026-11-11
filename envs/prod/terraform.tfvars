# Production values. No secrets and no account identifiers.
client      = "fnc"
project     = "aroma"
environment = "prod"
region      = "us-east-1"

vpc_cidr           = "10.70.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Production runs the full network. The environment comes up only while it is used, which limits its cost.
enable_center_link       = true
linked_centers           = [41, 42, 43]
enable_private_endpoints = true

# The demonstration holds no real data, so a destroy may remove it. The pilot sets this to false in production.
force_destroy_data = true

# Days a destroyed key stays recoverable before AWS deletes it.
key_deletion_window_in_days = 30

common_tags = {
  Client      = "fnc"
  Project     = "aroma"
  Environment = "prod"
  Owner       = "platform"
  CostCenter  = "plataforma"
  ManagedBy   = "Terraform"
}

departments = ["cauca", "huila", "tolima"]

sample_farm = {
  farm_id    = "farm-prod-0001"
  department = "cauca"
  node_id    = "node-prod-00001"
}
