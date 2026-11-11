# Data sources of bootstrap.
data "aws_caller_identity" "current" {
  provider = aws.principal
}

# Each state bucket refuses requests without TLS and principals outside its scope.
# Pipeline roles are matched by name, since they are created after the buckets. The bootstrap role
# manages every bucket, so each policy admits it too.
data "aws_iam_policy_document" "state" {
  for_each = local.state

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${each.value.bucket_name}",
      "arn:aws:s3:::${each.value.bucket_name}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "DenyOutsideScope"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${each.value.bucket_name}",
      "arn:aws:s3:::${each.value.bucket_name}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values = [
        each.value.pipeline_role_arn_pattern,
        local.bootstrap_role_arn,
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/*",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }
  }
}

# Trust of each pipeline role. Only a job of this repository that runs in the named GitHub
# environment can assume it.
data "aws_iam_policy_document" "pipeline_trust" {
  for_each = local.pipeline_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${var.github_subject_prefix}:environment:${each.value.github_environment}"]
    }
  }
}

# A plan role reads the account, keeps the state and saved plans of its own scope, and decrypts table
# items, since a plan refreshes table items under the data key.
data "aws_iam_policy_document" "plan_state" {
  for_each = { for key, role in local.pipeline_roles : key => role if role.kind == "plan" }

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.state[each.value.scope].bucket_name}"]
  }

  statement {
    sid       = "ReadAndWriteStateAndPlans"
    actions   = ["s3:DeleteObject", "s3:GetObject", "s3:PutObject"]
    resources = ["arn:aws:s3:::${local.state[each.value.scope].bucket_name}/*"]
  }

  statement {
    sid       = "UsePlatformKey"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.platform[each.value.scope].arn]
  }

  statement {
    sid       = "DecryptTableItems"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${var.region}.amazonaws.com"]
    }
  }
}
