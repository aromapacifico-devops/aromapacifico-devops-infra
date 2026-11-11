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

variable "saved_plan_days" {
  description = "Days a saved plan stays in the state bucket before it expires."
  type        = number
  default     = 30
}

variable "github_subject_prefix" {
  description = "Prefix of the OIDC subject of the infrastructure repository, in the immutable format repo:<owner>@<owner id>/<repo>@<repo id>."
  type        = string

  validation {
    condition     = can(regex("^repo:[A-Za-z0-9-]+@[0-9]+/[A-Za-z0-9._-]+@[0-9]+$", var.github_subject_prefix))
    error_message = "github_subject_prefix must look like repo:<owner>@<owner id>/<repo>@<repo id>."
  }
}

variable "budget_alert_email" {
  description = "Address that receives the budget alerts. It comes from the shared GitHub environment or the terminal, never from a committed file."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.budget_alert_email))
    error_message = "budget_alert_email must be an email address."
  }
}

variable "budget_alert_thresholds_usd" {
  description = "Monthly actual spend, in USD and without credits, that sends an alert. The highest is the budget limit."
  type        = list(number)
  default     = [20, 50]

  validation {
    condition     = length(var.budget_alert_thresholds_usd) > 0 && alltrue([for value in var.budget_alert_thresholds_usd : value > 0])
    error_message = "budget_alert_thresholds_usd needs at least one positive amount."
  }
}
