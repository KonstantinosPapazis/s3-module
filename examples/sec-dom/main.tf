provider "aws" {
  region = "us-east-1"
}

# Example: ABAC using company isolation tag "sec-dom"
module "abac_sec_dom_bucket" {
  source = "../.."

  bucket_name  = "example-sec-dom-bucket"
  abac_tag_key = "sec-dom"
  # Bucket gets this tag value; principals must carry the same session tag value.
  abac_bucket_tag_value = "payments"

  abac_principals = [
    "arn:aws:iam::123456789012:role/payments-app"
  ]

  tags = {
    env     = "dev"
    sec-dom = "payments"
  }
}

