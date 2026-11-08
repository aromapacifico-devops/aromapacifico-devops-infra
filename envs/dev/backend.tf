# Remote state of the dev environment, in its own bucket and encrypted with its platform key.
terraform {
  backend "s3" {
    bucket       = "fnc-aroma-dev-s3-tfstate"
    key          = "dev/us-east-1/platform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "alias/fnc-aroma-dev-kms-platform"
    use_lockfile = true
  }
}
