# Configuration payloads for the modules, with final resource names, are built here.
locals {
  name_prefix = "${var.client}-${var.project}-${var.environment}"

  vpc_name = "${local.name_prefix}-vpc-main"

  # Each purpose takes a /20 block in this order, and each zone inside it takes a /24.
  subnet_purposes = ["telemetry-ingress", "drone-ingress", "application", "data", "object-storage", "administration", "public-query"]

  subnets = merge([
    for purpose_index, purpose in local.subnet_purposes : {
      for zone_index, zone in var.availability_zones :
      "${purpose}-${substr(zone, -1, 1)}" => {
        name              = "${local.name_prefix}-subnet-${purpose}-${substr(zone, -1, 1)}"
        purpose           = purpose
        cidr              = cidrsubnet(var.vpc_cidr, 8, purpose_index * 16 + zone_index)
        availability_zone = zone
      }
    }
  ]...)
}
