provider "aws" {
  region = "us-east-1"
}

module "abac_bucket" {
  source = "../.."

  bucket_name           = "example-abac-bucket"
  abac_tag_key          = "team"
  abac_bucket_tag_value = "data-platform"
  abac_principals = [
    "arn:aws:iam::123456789012:role/data-platform-role"
  ]

  tags = {
    env  = "dev"
    team = "data-platform"
  }
}

