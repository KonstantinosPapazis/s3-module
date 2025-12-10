provider "aws" {
  region = "us-east-1"
}

module "s3_access_grants" {
  source = "../.."

  bucket_name  = "example-access-grants-bucket"
  enable_abac  = false
  tags = {
    env = "dev"
  }

  access_grants = {
    account_id         = "123456789012"
    identity_center_arn = "arn:aws:sso:::instance/ssoins-example123456789"
    iam_role_arn       = "arn:aws:iam::123456789012:role/s3-access-grants-runtime"
    location_scope     = "s3://"
    grants = [
      {
        permission         = "READ"
        grantee_type       = "IAM"
        grantee_identifier = "arn:aws:iam::123456789012:user/data-reader"
        s3_prefix_type     = "Object"
        s3_sub_prefix      = "reports/*"
      }
    ]
  }

  directory_bucket = {
    bucket = "example--usw2-az1--x-s3"
    location = {
      name = "usw2-az1"
    }
    tags = {
      env = "dev"
    }
  }

  object_lambda_access_points = [
    {
      name                    = "transform-get-object"
      supporting_access_point = "arn:aws:s3:us-east-1:123456789012:accesspoint/example-ap"
      transformation_actions  = ["GetObject"]
      lambda = {
        function_arn = "arn:aws:lambda:us-east-1:123456789012:function:object-transform"
      }
    }
  ]
}

