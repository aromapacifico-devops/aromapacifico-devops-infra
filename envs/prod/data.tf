# Data sources of the root. They read the account, Region and partition the provider works in.
data "aws_caller_identity" "current" {
  provider = aws.principal
}

data "aws_region" "current" {
  provider = aws.principal
}

data "aws_partition" "current" {
  provider = aws.principal
}

data "aws_iot_endpoint" "data" {
  provider = aws.principal

  endpoint_type = "iot:Data-ATS"
}

# Function packages, zipped from the code in functions/ at the root of the repository.
data "archive_file" "functions" {
  for_each = toset(["ingestion", "placeholder"])

  type             = "zip"
  source_dir       = "${path.module}/../../functions/${each.key}"
  output_path      = "${path.module}/.build/${each.key}.zip"
  output_file_mode = "0644"
}
