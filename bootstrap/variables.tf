# Input variables of bootstrap. Values live in terraform.tfvars.
variable "client" {
  description = "Client code, used in names."
  type        = string
}

variable "project" {
  description = "Project code, used in names."
  type        = string
}

variable "environments" {
  description = "Environments that get a state bucket and a platform key. Bootstrap adds its own shared scope."
  type        = list(string)

  validation {
    condition     = alltrue([for env in var.environments : contains(["dev", "test", "prod"], env)])
    error_message = "environments may only contain dev, test and prod."
  }
}

variable "region" {
  description = "AWS Region of the shared resources."
  type        = string
}

variable "deploy_role_arn" {
  description = "Role the provider assumes. Leave empty to use the local credentials."
  type        = string
  default     = ""
}

variable "state_noncurrent_version_days" {
  description = "Days a replaced state version is kept before it expires."
  type        = number
  default     = 90
}

variable "common_tags" {
  description = "Tags applied to every resource through the provider."
  type        = map(string)
}
