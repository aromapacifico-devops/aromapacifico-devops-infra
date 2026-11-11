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

# Pipeline roles. Each environment has a plan role, trusted by its plan environment, and an apply role,
# trusted by the environment that deploys it. The bootstrap role lives in the shared scope.
locals {
  name_prefix        = "${var.client}-${var.project}"
  bootstrap_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-shared-role-pipeline-bootstrap"

  pipeline_roles = merge(
    {
      for env in var.environments : "${env}-plan" => {
        name               = "${local.name_prefix}-${env}-role-pipeline-plan"
        scope              = env
        kind               = "plan"
        github_environment = "plan-${env}"
        managed_policy     = "ReadOnlyAccess"
      }
    },
    {
      for env in var.environments : "${env}-apply" => {
        name               = "${local.name_prefix}-${env}-role-pipeline-apply"
        scope              = env
        kind               = "apply"
        github_environment = env
        managed_policy     = "AdministratorAccess"
      }
    },
    {
      bootstrap = {
        name               = "${local.name_prefix}-shared-role-pipeline-bootstrap"
        scope              = "shared"
        kind               = "bootstrap"
        github_environment = "shared"
        managed_policy     = "AdministratorAccess"
      }
    },
  )
}
