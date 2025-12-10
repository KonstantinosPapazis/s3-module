provider "aws" {
  region = "us-east-1"
}

module "s3_full" {
  source = "../.."

  bucket_name   = "example-full-bucket"
  kms_key_id    = null
  abac_tag_key  = "project"
  abac_principals = [
    "arn:aws:iam::123456789012:role/abac-project-role"
  ]

  lifecycle_rules = [
    {
      id                                     = "transition-archive"
      enabled                                = true
      abort_incomplete_multipart_upload_days = 7
      prefix                                 = "logs/"
      expiration = {
        days                         = 365
        expired_object_delete_marker = false
      }
      noncurrent_version_expiration = {
        days = 180
      }
      noncurrent_version_transitions = [
        {
          days          = 90
          storage_class = "STANDARD_IA"
        }
      ]
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 120
          storage_class = "GLACIER"
        }
      ]
      filter = {
        prefix = "logs/"
      }
    }
  ]

  cors_rules = [
    {
      id              = "web-app"
      allowed_methods = ["GET", "PUT"]
      allowed_origins = ["https://app.example.com"]
      allowed_headers = ["*"]
      expose_headers  = ["ETag"]
      max_age_seconds = 3600
    }
  ]

  replication_configuration = {
    role = "arn:aws:iam::123456789012:role/replication-role"
    rules = [
      {
        id       = "replicate-logs"
        priority = 1
        status   = "Enabled"
        filter = {
          prefix = "logs/"
        }
        destination = {
          bucket        = "arn:aws:s3:::example-replication-dest"
          storage_class = "STANDARD_IA"
          account       = "123456789012"
          access_control_translation = {
            owner = "Destination"
          }
          replica_kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
        }
      }
    ]
  }

  intelligent_tiering_configurations = [
    {
      name = "default-tiering"
      filter = {
        prefix = ""
      }
      tierings = [
        {
          access_tier = "ARCHIVE_ACCESS"
          days        = 60
        },
        {
          access_tier = "DEEP_ARCHIVE_ACCESS"
          days        = 180
        }
      ]
    }
  ]

  inventory_configurations = [
    {
      name                     = "daily-inventory"
      schedule_frequency       = "Daily"
      included_object_versions = "Current"
      optional_fields          = ["Size", "StorageClass"]
      destination = {
        format     = "CSV"
        bucket_arn = "arn:aws:s3:::example-inventory-dest"
        prefix     = "inventory/"
      }
    }
  ]

  metric_configuration = [
    {
      name = "all-objects"
      filter = {
        prefix = ""
      }
    }
  ]

  analytics_configuration = [
    {
      name = "all-objects-analytics"
      filter = {
        prefix = ""
      }
      destination = {
        bucket_arn = "arn:aws:s3:::example-analytics-dest"
        format     = "CSV"
        prefix     = "analytics/"
      }
      output_schema_version = "V_1"
    }
  ]

  notifications = {
    lambda = [
      {
        id                  = "lambda-on-object"
        lambda_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:on-object"
        events              = ["s3:ObjectCreated:*"]
        filter_prefix       = "uploads/"
        filter_suffix       = ".json"
      }
    ]
    sqs = [
      {
        id            = "queue-on-delete"
        queue_arn     = "arn:aws:sqs:us-east-1:123456789012:bucket-events"
        events        = ["s3:ObjectRemoved:*"]
        filter_prefix = "uploads/"
      }
    ]
    sns = [
      {
        id        = "topic-on-multipart"
        topic_arn = "arn:aws:sns:us-east-1:123456789012:bucket-events"
        events    = ["s3:ReducedRedundancyLostObject"]
      }
    ]
  }

  website = {
    index_document = "index.html"
    error_document = "404.html"
  }

  enable_transfer_acceleration = true

  tags = {
    env     = "dev"
    project = "abac-demo"
  }
}

