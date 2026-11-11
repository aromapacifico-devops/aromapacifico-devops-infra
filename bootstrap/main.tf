# Shared resources created once, which every environment depends on.

# Platform key of each scope. It encrypts the Terraform state.
resource "aws_kms_key" "platform" {
  provider = aws.principal
  for_each = local.state

  description             = "Platform key of ${each.key}, encrypts the Terraform state"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Environment = each.key
  }
}

resource "aws_kms_alias" "platform" {
  provider = aws.principal
  for_each = local.state

  name          = each.value.key_alias
  target_key_id = aws_kms_key.platform[each.key].key_id
}

resource "aws_s3_bucket" "state" {
  provider = aws.principal
  for_each = local.state

  bucket = each.value.bucket_name

  tags = {
    Environment = each.key
  }
}

resource "aws_s3_bucket_ownership_controls" "state" {
  provider = aws.principal
  for_each = local.state

  bucket = aws_s3_bucket.state[each.key].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  provider = aws.principal
  for_each = local.state

  bucket                  = aws_s3_bucket.state[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "state" {
  provider = aws.principal
  for_each = local.state

  bucket = aws_s3_bucket.state[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  provider = aws.principal
  for_each = local.state

  bucket = aws_s3_bucket.state[each.key].id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.platform[each.key].arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  provider = aws.principal
  for_each = local.state

  bucket = aws_s3_bucket.state[each.key].id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.state_noncurrent_version_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Saved plans can hold sensitive values, so they leave the bucket once nobody needs them.
  rule {
    id     = "expire-saved-plans"
    status = "Enabled"

    filter {
      prefix = "plans/"
    }

    expiration {
      days = var.saved_plan_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

resource "aws_s3_bucket_policy" "state" {
  provider = aws.principal
  for_each = local.state

  bucket = aws_s3_bucket.state[each.key].id
  policy = data.aws_iam_policy_document.state[each.key].json

  depends_on = [aws_s3_bucket_public_access_block.state]
}

# One GitHub OIDC provider per account, which every pipeline role trusts.
resource "aws_iam_openid_connect_provider" "github" {
  provider = aws.principal

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Environment = "shared"
  }
}

resource "aws_iam_role" "pipeline" {
  provider = aws.principal
  for_each = local.pipeline_roles

  name                 = each.value.name
  assume_role_policy   = data.aws_iam_policy_document.pipeline_trust[each.key].json
  max_session_duration = 3600

  tags = {
    Environment = each.value.scope
  }
}

resource "aws_iam_role_policy_attachment" "pipeline" {
  provider = aws.principal
  for_each = local.pipeline_roles

  role       = aws_iam_role.pipeline[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/${each.value.managed_policy}"
}

resource "aws_iam_role_policy" "plan_state" {
  provider = aws.principal
  for_each = data.aws_iam_policy_document.plan_state

  name   = "${aws_iam_role.pipeline[each.key].name}-state"
  role   = aws_iam_role.pipeline[each.key].id
  policy = each.value.json
}

# Account budget. Credits are left out, so the alerts follow real usage while credits still pay for it.
resource "aws_budgets_budget" "account" {
  provider = aws.principal

  name         = "${local.name_prefix}-account-budget"
  budget_type  = "COST"
  limit_amount = tostring(max(var.budget_alert_thresholds_usd...))
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit = false
    include_refund = false
  }

  dynamic "notification" {
    for_each = toset(var.budget_alert_thresholds_usd)

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "ABSOLUTE_VALUE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.budget_alert_email]
    }
  }

  tags = {
    Environment = "shared"
  }
}
