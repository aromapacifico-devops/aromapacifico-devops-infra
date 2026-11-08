# Bootstrap keeps its own state in the shared bucket it creates. The first run starts with local state and migrates.
terraform {
  backend "s3" {
    bucket       = "fnc-aroma-shared-s3-tfstate"
    key          = "shared/us-east-1/bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "alias/fnc-aroma-shared-kms-platform"
    use_lockfile = true
  }
}
