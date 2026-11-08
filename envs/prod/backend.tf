# Remote state of the prod environment, in its own bucket and encrypted with its platform key.
terraform {
  backend "s3" {
    bucket       = "fnc-aroma-prod-s3-tfstate"
    key          = "prod/us-east-1/platform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "alias/fnc-aroma-prod-kms-platform"
    use_lockfile = true
  }
}
