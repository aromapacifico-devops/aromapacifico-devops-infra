# Input variables of bootstrap. Values live in terraform.tfvars.
variable "region" {
  description = "AWS Region of the shared resources."
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
}
