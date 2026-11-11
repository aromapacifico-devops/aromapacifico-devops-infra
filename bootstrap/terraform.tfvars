# Bootstrap values. No secrets and no account identifiers.
client       = "fnc"
project      = "aroma"
environments = ["dev", "test", "prod"]
region       = "us-east-1"

# OIDC subject prefix of the infrastructure repository. Owner and repository IDs are public.
github_subject_prefix = "repo:aromapacifico-devops@352295207/aromapacifico-devops-infra@1446256508"

common_tags = {
  Client      = "fnc"
  Project     = "aroma"
  Environment = "shared"
  Owner       = "platform"
  CostCenter  = "plataforma"
  ManagedBy   = "Terraform"
}
