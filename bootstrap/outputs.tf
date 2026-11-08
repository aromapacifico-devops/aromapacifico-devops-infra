# Outputs that the environments and the pipeline read.
output "state_bucket_names" {
  description = "State bucket name of each scope."
  value       = { for scope, bucket in aws_s3_bucket.state : scope => bucket.bucket }
}

output "platform_key_arns" {
  description = "Platform key ARN of each scope."
  value       = { for scope, key in aws_kms_key.platform : scope => key.arn }
}
