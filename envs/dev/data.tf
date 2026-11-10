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
