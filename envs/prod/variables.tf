# Input variables of the root. Values live in terraform.tfvars.
variable "client" {
  description = "Client code, used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.client))
    error_message = "client must be 1 to 10 lowercase alphanumeric characters."
  }
}

variable "project" {
  description = "Project code, used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,15}$", var.project))
    error_message = "project must be 1 to 15 lowercase alphanumeric characters."
  }
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

variable "vpc_cidr" {
  description = "Range of the environment VPC, a /16 outside the ranges reserved for collection centers."
  type        = string

  validation {
    condition     = try(split("/", var.vpc_cidr)[1] == "16" && cidrhost(var.vpc_cidr, 0) == split("/", var.vpc_cidr)[0], false)
    error_message = "vpc_cidr must be a /16 written from its network address, such as 10.60.0.0/16."
  }

  validation {
    condition     = try(split(".", var.vpc_cidr)[0] == "10" && !contains([for octet in range(41, 50) : tostring(octet)], split(".", var.vpc_cidr)[1]), false)
    error_message = "vpc_cidr must sit inside 10.0.0.0/8 and outside 10.41.0.0/16 to 10.49.0.0/16, which belong to collection centers."
  }
}

variable "availability_zones" {
  description = "Availability zones of the environment. Each subnet purpose gets one subnet per zone."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 1 && length(var.availability_zones) <= 3 && length(distinct(var.availability_zones)) == length(var.availability_zones)
    error_message = "availability_zones must list one to three distinct zones."
  }

  validation {
    condition     = alltrue([for zone in var.availability_zones : can(regex("^${var.region}[a-z]$", zone))])
    error_message = "availability_zones must belong to the Region of the environment."
  }
}

variable "enable_center_link" {
  description = "Creates the VPN links to the collection centers, the main hourly cost of an environment."
  type        = bool
  default     = false
}

variable "enable_private_endpoints" {
  description = "Creates the interface endpoints, the other hourly cost of an environment."
  type        = bool
  default     = false
}

variable "force_destroy_data" {
  description = "Lets a destroy remove tables and buckets that still hold data."
  type        = bool
  default     = false
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

  validation {
    condition     = try(var.common_tags["Client"] == var.client && var.common_tags["Project"] == var.project && var.common_tags["Environment"] == var.environment, false)
    error_message = "common_tags Client, Project and Environment must match client, project and environment."
  }

  validation {
    condition     = try(contains(["fincas", "drones", "acopio", "viajes", "pruebas", "plataforma", "seguridad"], var.common_tags["CostCenter"]) && var.common_tags["ManagedBy"] == "Terraform", false)
    error_message = "common_tags CostCenter must be one of the documented cost centers, and ManagedBy must be Terraform."
  }
}

variable "key_deletion_window_in_days" {
  description = "Days a destroyed KMS key waits before AWS deletes it, 7 to 30."
  type        = number

  validation {
    condition     = var.key_deletion_window_in_days >= 7 && var.key_deletion_window_in_days <= 30 && floor(var.key_deletion_window_in_days) == var.key_deletion_window_in_days
    error_message = "key_deletion_window_in_days must be a whole number from 7 to 30."
  }
}
