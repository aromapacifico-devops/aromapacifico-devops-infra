# Main provider of the root. Modules receive it as aws.project.
provider "aws" {
  alias  = "principal"
  region = var.region

  dynamic "assume_role" {
    for_each = var.deploy_role_arn == "" ? [] : [var.deploy_role_arn]

    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = var.common_tags
  }
}
