# Bootstrap values. No secrets and no account identifiers.
client       = "fnc"
project      = "aroma"
environments = ["dev", "test", "prod"]
region       = "us-east-1"

common_tags = {
  Client      = "fnc"
  Project     = "aroma"
  Environment = "shared"
  Owner       = "platform"
  CostCenter  = "plataforma"
  ManagedBy   = "Terraform"
}
