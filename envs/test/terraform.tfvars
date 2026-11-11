# Test values. No secrets and no account identifiers.
client      = "fnc"
project     = "aroma"
environment = "test"
region      = "us-east-1"

vpc_cidr           = "10.60.0.0/16"
availability_zones = ["us-east-1a"]

# Billed items stay off. Turn them on for a session that validates the center link or the endpoints.
enable_center_link       = false
linked_centers           = [41]
enable_private_endpoints = false

# Holds no real data, so a destroy may remove it.
force_destroy_data = true

# Days a destroyed key stays recoverable before AWS deletes it.
key_deletion_window_in_days = 7

common_tags = {
  Client      = "fnc"
  Project     = "aroma"
  Environment = "test"
  Owner       = "platform"
  CostCenter  = "plataforma"
  ManagedBy   = "Terraform"
}
