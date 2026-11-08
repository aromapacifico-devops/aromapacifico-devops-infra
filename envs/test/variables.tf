# Input variables of the root. Values live in terraform.tfvars.
variable "client" {
  description = "Client code, used in names and tags."
  type        = string
}

variable "project" {
  description = "Project code, used in names and tags."
  type        = string
}

variable "environment" {
  description = "Deployment environment of this root."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "region" {
  description = "AWS Region of the environment."
  type        = string
}

variable "deploy_role_arn" {
  description = "Role the provider assumes. Leave empty to use the local credentials."
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Tags applied to every resource through the provider."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["Client", "Project", "Environment", "Owner", "CostCenter", "ManagedBy"] : contains(keys(var.common_tags), key)
    ])
    error_message = "common_tags must include Client, Project, Environment, Owner, CostCenter and ManagedBy."
  }
}
