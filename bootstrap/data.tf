# Data sources of bootstrap.
data "aws_caller_identity" "current" {
  provider = aws.principal
}

# Each state bucket refuses requests without TLS and principals outside its scope.
# Pipeline roles are matched by name, since they are created after the buckets.
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
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/*",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }
  }
}
