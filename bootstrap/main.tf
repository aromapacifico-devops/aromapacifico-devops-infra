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

  depends_on = [aws_s3_bucket_versioning.state]
}

resource "aws_s3_bucket_policy" "state" {
  provider = aws.principal
  for_each = local.state

  bucket = aws_s3_bucket.state[each.key].id
  policy = data.aws_iam_policy_document.state[each.key].json

  depends_on = [aws_s3_bucket_public_access_block.state]
}
