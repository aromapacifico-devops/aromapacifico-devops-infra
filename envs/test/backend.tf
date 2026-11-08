# Remote state of the test environment, in its own bucket and encrypted with its platform key.
terraform {
  backend "s3" {
    bucket       = "fnc-aroma-test-s3-tfstate"
    key          = "test/us-east-1/platform/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "alias/fnc-aroma-test-kms-platform"
    use_lockfile = true
  }
}
