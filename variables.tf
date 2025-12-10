variable "bucket_name" {
  description = "Name for the S3 bucket."
  type        = string
}

variable "object_ownership" {
  description = "S3 object ownership setting."
  type        = string
  default     = "BucketOwnerEnforced"

  validation {
    condition     = contains(["BucketOwnerEnforced", "ObjectWriter", "BucketOwnerPreferred"], var.object_ownership)
    error_message = "object_ownership must be BucketOwnerEnforced, ObjectWriter, or BucketOwnerPreferred."
  }
}

variable "force_destroy" {
  description = "Whether to allow destroying the bucket even if it contains objects."
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable S3 versioning."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID or ARN to use for default encryption. Leave null for SSE-S3."
  type        = string
  default     = null
}

variable "block_public_acls" {
  description = "Block public ACLs on the bucket."
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public bucket policies."
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs."
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict cross-account public bucket policies."
  type        = bool
  default     = true
}

variable "create_public_access_block" {
  description = "Create a Public Access Block resource."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}

variable "enable_abac" {
  description = "Create an ABAC policy for the bucket."
  type        = bool
  default     = true
}

variable "abac_tag_key" {
  description = "Tag key used for ABAC matching between principals and objects."
  type        = string

  validation {
    condition     = length(var.abac_tag_key) > 0
    error_message = "abac_tag_key cannot be empty."
  }
}

variable "abac_bucket_tag_value" {
  description = "Tag value to place on the bucket for ABAC-aware principals to match."
  type        = string
  default     = "abac-enabled"
}

variable "abac_principals" {
  description = "AWS principal ARNs that are allowed via ABAC. Required when ABAC is enabled."
  type        = set(string)
  default     = []

  validation {
    condition     = var.enable_abac == false || length(var.abac_principals) > 0
    error_message = "Provide at least one principal ARN when ABAC is enabled."
  }
}

variable "abac_object_actions" {
  description = "Object-level actions allowed when ABAC conditions match."
  type        = list(string)
  default = [
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:AbortMultipartUpload",
    "s3:ListBucketMultipartUploads",
    "s3:PutObjectTagging",
    "s3:GetObjectTagging"
  ]
}

variable "expected_bucket_owner" {
  description = "Expected bucket owner for policy operations."
  type        = string
  default     = null
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for the bucket."
  type = list(object({
    id                                     = string
    enabled                                = bool
    abort_incomplete_multipart_upload_days = optional(number)
    prefix                                 = optional(string)
    expiration = optional(object({
      days                         = optional(number)
      expired_object_delete_marker = optional(bool)
    }))
    noncurrent_version_expiration = optional(object({
      days = number
    }))
    noncurrent_version_transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    transitions = optional(list(object({
      days          = number
      storage_class = string
    })), [])
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
  }))
  default = []
}

variable "cors_rules" {
  description = "CORS rules for the bucket."
  type = list(object({
    id              = optional(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    allowed_headers = optional(list(string), [])
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number)
  }))
  default = []
}

variable "replication_configuration" {
  description = "Replication configuration for the bucket."
  type = object({
    role  = string
    rules = list(object({
      id       = string
      priority = number
      status   = string
      filter = optional(object({
        prefix = optional(string)
        tags   = optional(map(string))
      }))
      destination = object({
        bucket             = string
        storage_class      = optional(string)
        replica_kms_key_id = optional(string)
        account            = optional(string)
        access_control_translation = optional(object({
          owner = string
        }))
        replication_time = optional(object({
          status  = string
          minutes = optional(number)
        }))
        metrics = optional(object({
          status  = string
          minutes = optional(number)
        }))
      })
    }))
  })
  default = null
}

variable "intelligent_tiering_configurations" {
  description = "Intelligent tiering configurations."
  type = list(object({
    name = string
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
    tierings = list(object({
      access_tier = string
      days        = number
    }))
  }))
  default = []
}

variable "inventory_configurations" {
  description = "Bucket inventory configurations."
  type = list(object({
    name                     = string
    schedule_frequency       = string
    included_object_versions = string
    optional_fields          = optional(list(string), [])
    destination = object({
      format     = string
      bucket_arn = string
      account_id = optional(string)
      prefix     = optional(string)
    })
  }))
  default = []
}

variable "metric_configuration" {
  description = "Bucket metrics configurations."
  type = list(object({
    name = string
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
  }))
  default = []
}

variable "analytics_configuration" {
  description = "Bucket analytics configurations."
  type = list(object({
    name = string
    filter = optional(object({
      prefix = optional(string)
      tags   = optional(map(string))
    }))
    destination = object({
      bucket_arn = string
      format     = string
      prefix     = optional(string)
    })
    output_schema_version = string
  }))
  default = []
}

variable "website" {
  description = "Website hosting configuration."
  type = object({
    index_document = optional(string)
    error_document = optional(string)
    redirect_all_requests_to = optional(object({
      host_name = string
      protocol  = string
    }))
    routing_rules = optional(string)
  })
  default = null
}

variable "notifications" {
  description = "Bucket notifications."
  type = object({
    lambda = optional(list(object({
      id                  = string
      lambda_function_arn = string
      events              = list(string)
      filter_prefix       = optional(string)
      filter_suffix       = optional(string)
    })))
    sqs = optional(list(object({
      id            = string
      queue_arn     = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })))
    sns = optional(list(object({
      id            = string
      topic_arn     = string
      events        = list(string)
      filter_prefix = optional(string)
      filter_suffix = optional(string)
    })))
  })
  default = null
}

variable "enable_transfer_acceleration" {
  description = "Enable S3 Transfer Acceleration."
  type        = bool
  default     = false
}

variable "directory_bucket" {
  description = "Configuration for S3 Express directory bucket."
  type = object({
    bucket        = string
    force_destroy = optional(bool, false)
    data_redundancy = optional(string)
    location = object({
      name = string
      type = optional(string, "AvailabilityZone")
    })
    tags = optional(map(string), {})
  })
  default = null
}

variable "access_grants" {
  description = "S3 Access Grants configuration."
  type = object({
    account_id         = optional(string)
    identity_center_arn = optional(string)
    iam_role_arn       = string
    location_scope     = string
    grants = list(object({
      permission         = string
      grantee_type       = string
      grantee_identifier = string
      s3_prefix_type     = optional(string)
      s3_sub_prefix      = optional(string)
    }))
    tags = optional(map(string), {})
  })
  default = null
}

variable "object_lambda_access_points" {
  description = "S3 Object Lambda access point configurations."
  type = list(object({
    name                        = string
    account_id                  = optional(string)
    supporting_access_point     = string
    cloud_watch_metrics_enabled = optional(bool)
    allowed_features            = optional(list(string))
    transformation_actions      = list(string)
    lambda = object({
      function_arn     = string
      function_payload = optional(string)
    })
  }))
  default = []
}

