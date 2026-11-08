# Names and access scope of each state bucket. Bootstrap keeps its own state in the shared scope.
locals {
  state_scopes = toset(concat(["shared"], var.environments))

  state = {
    for scope in local.state_scopes : scope => {
      bucket_name               = "${var.client}-${var.project}-${scope}-s3-tfstate"
      key_alias                 = "alias/${var.client}-${var.project}-${scope}-kms-platform"
      pipeline_role_arn_pattern = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.client}-${var.project}-${scope}-role-pipeline-*"
    }
  }
}
