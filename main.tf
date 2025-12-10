terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.18"
    }
  }
}

data "aws_region" "current" {}

locals {
  bucket_tags = merge(
    var.tags,
    var.enable_abac ? { (var.abac_tag_key) = var.abac_bucket_tag_value } : {}
  )
}

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = local.bucket_tags
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days == null ? [] : [rule.value.abort_incomplete_multipart_upload_days]
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value
        }
      }

      dynamic "filter" {
        for_each = rule.value.filter == null ? [] : [rule.value.filter]
        content {
          prefix = try(filter.value.prefix, null)
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration == null ? [] : [rule.value.expiration]
        content {
          days                         = try(expiration.value.days, null)
          expired_object_delete_marker = try(expiration.value.expired_object_delete_marker, null)
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration == null ? [] : [rule.value.noncurrent_version_expiration]
        content {
          noncurrent_days = noncurrent_version_expiration.value.days
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transitions
        content {
          noncurrent_days = noncurrent_version_transition.value.days
          storage_class   = noncurrent_version_transition.value.storage_class
        }
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = var.object_ownership
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  count = var.create_public_access_block ? 1 : 0

  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_id
      sse_algorithm     = var.kms_key_id == null ? "AES256" : "aws:kms"
    }
  }
}

resource "aws_s3_bucket_website_configuration" "this" {
  count  = var.website == null ? 0 : 1
  bucket = aws_s3_bucket.this.id

  dynamic "index_document" {
    for_each = var.website.index_document == null ? [] : [var.website.index_document]
    content {
      suffix = index_document.value
    }
  }

  dynamic "error_document" {
    for_each = var.website.error_document == null ? [] : [var.website.error_document]
    content {
      key = error_document.value
    }
  }

  dynamic "redirect_all_requests_to" {
    for_each = var.website.redirect_all_requests_to == null ? [] : [var.website.redirect_all_requests_to]
    content {
      host_name = redirect_all_requests_to.value.host_name
      protocol  = redirect_all_requests_to.value.protocol
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "this" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      id              = cors_rule.value.id
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      allowed_headers = cors_rule.value.allowed_headers
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "this" {
  count = var.replication_configuration == null ? 0 : 1

  role   = var.replication_configuration.role
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.replication_configuration.rules
    content {
      id       = rule.value.id
      status   = rule.value.status
      priority = rule.value.priority

      dynamic "filter" {
        for_each = rule.value.filter == null ? [] : [rule.value.filter]
        content {
          prefix = try(filter.value.prefix, null)
        }
      }

      destination {
        bucket             = rule.value.destination.bucket
        storage_class      = try(rule.value.destination.storage_class, null)
        account            = try(rule.value.destination.account, null)

        dynamic "access_control_translation" {
          for_each = try(rule.value.destination.access_control_translation, null) == null ? [] : [rule.value.destination.access_control_translation]
          content {
            owner = access_control_translation.value.owner
          }
        }

        dynamic "encryption_configuration" {
          for_each = try(rule.value.destination.replica_kms_key_id, null) == null ? [] : [rule.value.destination.replica_kms_key_id]
          content {
            replica_kms_key_id = encryption_configuration.value
          }
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  for_each = { for cfg in var.intelligent_tiering_configurations : cfg.name => cfg }

  bucket = aws_s3_bucket.this.id
  name   = each.value.name

  dynamic "filter" {
    for_each = each.value.filter == null ? [] : [each.value.filter]
    content {
      prefix = try(filter.value.prefix, null)
      tags   = try(filter.value.tags, null)
    }
  }

  dynamic "tiering" {
    for_each = each.value.tierings
    content {
      access_tier = tiering.value.access_tier
      days        = tiering.value.days
    }
  }
}

resource "aws_s3_bucket_inventory" "this" {
  for_each = { for inv in var.inventory_configurations : inv.name => inv }

  bucket = aws_s3_bucket.this.id
  name   = each.value.name

  destination {
    bucket {
      format     = each.value.destination.format
      bucket_arn = each.value.destination.bucket_arn
      account_id = try(each.value.destination.account_id, null)
      prefix     = try(each.value.destination.prefix, null)
    }
  }

  included_object_versions = each.value.included_object_versions
  optional_fields          = each.value.optional_fields

  schedule {
    frequency = each.value.schedule_frequency
  }
}

resource "aws_s3_bucket_metric" "this" {
  for_each = { for m in var.metric_configuration : m.name => m }

  bucket = aws_s3_bucket.this.id
  name   = each.value.name

  dynamic "filter" {
    for_each = each.value.filter == null ? [] : [each.value.filter]
    content {
      prefix = try(filter.value.prefix, null)
      tags   = try(filter.value.tags, null)
    }
  }
}

resource "aws_s3_bucket_analytics_configuration" "this" {
  for_each = { for a in var.analytics_configuration : a.name => a }

  bucket = aws_s3_bucket.this.id
  name   = each.value.name

  dynamic "filter" {
    for_each = each.value.filter == null ? [] : [each.value.filter]
    content {
      prefix = try(filter.value.prefix, null)
      tags   = try(filter.value.tags, null)
    }
  }

  storage_class_analysis {
    data_export {
      destination {
        s3_bucket_destination {
          bucket_arn = each.value.destination.bucket_arn
          format     = each.value.destination.format
          prefix     = try(each.value.destination.prefix, null)
        }
      }
      output_schema_version = each.value.output_schema_version
    }
  }
}

resource "aws_s3_bucket_notification" "this" {
  count = var.notifications == null ? 0 : 1
  bucket = aws_s3_bucket.this.id

  dynamic "lambda_function" {
    for_each = var.notifications.lambda == null ? [] : var.notifications.lambda
    content {
      id                  = lambda_function.value.id
      lambda_function_arn = lambda_function.value.lambda_function_arn
      events              = lambda_function.value.events
      filter_prefix       = lambda_function.value.filter_prefix
      filter_suffix       = lambda_function.value.filter_suffix
    }
  }

  dynamic "queue" {
    for_each = var.notifications.sqs == null ? [] : var.notifications.sqs
    content {
      id            = queue.value.id
      queue_arn     = queue.value.queue_arn
      events        = queue.value.events
      filter_prefix = queue.value.filter_prefix
      filter_suffix = queue.value.filter_suffix
    }
  }

  dynamic "topic" {
    for_each = var.notifications.sns == null ? [] : var.notifications.sns
    content {
      id            = topic.value.id
      topic_arn     = topic.value.topic_arn
      events        = topic.value.events
      filter_prefix = topic.value.filter_prefix
      filter_suffix = topic.value.filter_suffix
    }
  }
}

resource "aws_s3_bucket_policy" "abac" {
  count  = var.enable_abac ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.abac[0].json

  depends_on = [
    aws_s3_bucket_public_access_block.this
  ]
}

data "aws_iam_policy_document" "abac" {
  count = var.enable_abac ? 1 : 0

  statement {
    sid    = "DenyUntaggedPrincipals"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = var.abac_principals
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]

    condition {
      test     = "Null"
      variable = "aws:PrincipalTag/${var.abac_tag_key}"
      values   = ["true"]
    }
  }

  statement {
    sid    = "AllowListForMatchingTag"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.abac_principals
    }

    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]

    condition {
      test     = "StringEquals"
      variable = "s3:ResourceTag/${var.abac_tag_key}"
      values   = ["$${aws:PrincipalTag/${var.abac_tag_key}}"]
    }
  }

  statement {
    sid    = "AllowObjectAccessForMatchingTag"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.abac_principals
    }

    actions   = var.abac_object_actions
    resources = ["${aws_s3_bucket.this.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:ExistingObjectTag/${var.abac_tag_key}"
      values   = ["$${aws:PrincipalTag/${var.abac_tag_key}}"]
    }
  }

  statement {
    sid    = "RequireTagOnWrite"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = var.abac_principals
    }

    actions = ["s3:PutObject", "s3:PutObjectTagging", "s3:ReplicateObject", "s3:RestoreObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:RequestObjectTag/${var.abac_tag_key}"
      values   = ["$${aws:PrincipalTag/${var.abac_tag_key}}"]
    }
  }
}

resource "aws_s3_bucket_accelerate_configuration" "this" {
  count = var.enable_transfer_acceleration ? 1 : 0
  bucket = aws_s3_bucket.this.id
  status = "Enabled"
}

resource "aws_s3_directory_bucket" "this" {
  count = var.directory_bucket == null ? 0 : 1

  bucket         = var.directory_bucket.bucket
  force_destroy  = var.directory_bucket.force_destroy
  data_redundancy = var.directory_bucket.data_redundancy
  type           = "Directory"

  location {
    name = var.directory_bucket.location.name
    type = var.directory_bucket.location.type
  }

  tags = var.directory_bucket.tags
}

resource "aws_s3control_access_grants_instance" "this" {
  count = var.access_grants == null ? 0 : 1

  account_id         = try(var.access_grants.account_id, null)
  identity_center_arn = try(var.access_grants.identity_center_arn, null)
  tags               = try(var.access_grants.tags, null)
}

resource "aws_s3control_access_grants_location" "this" {
  count = var.access_grants == null ? 0 : 1

  depends_on = [aws_s3control_access_grants_instance.this]

  account_id    = try(var.access_grants.account_id, null)
  iam_role_arn  = var.access_grants.iam_role_arn
  location_scope = var.access_grants.location_scope
  tags          = try(var.access_grants.tags, null)
}

resource "aws_s3control_access_grant" "this" {
  count = var.access_grants == null ? 0 : length(var.access_grants.grants)

  access_grants_location_id = aws_s3control_access_grants_location.this[0].access_grants_location_id
  permission                = var.access_grants.grants[count.index].permission
  s3_prefix_type            = try(var.access_grants.grants[count.index].s3_prefix_type, null)
  account_id                = try(var.access_grants.account_id, null)

  access_grants_location_configuration {
    s3_sub_prefix = try(var.access_grants.grants[count.index].s3_sub_prefix, null)
  }

  grantee {
    grantee_type       = var.access_grants.grants[count.index].grantee_type
    grantee_identifier = var.access_grants.grants[count.index].grantee_identifier
  }

  tags = try(var.access_grants.tags, null)
}

resource "aws_s3control_object_lambda_access_point" "this" {
  for_each = { for olap in var.object_lambda_access_points : olap.name => olap }

  name       = each.value.name
  account_id = try(each.value.account_id, null)

  configuration {
    supporting_access_point = each.value.supporting_access_point
    cloud_watch_metrics_enabled = try(each.value.cloud_watch_metrics_enabled, null)
    allowed_features            = try(each.value.allowed_features, null)

    transformation_configuration {
      actions = each.value.transformation_actions

      content_transformation {
        aws_lambda {
          function_arn    = each.value.lambda.function_arn
          function_payload = try(each.value.lambda.function_payload, null)
        }
      }
    }
  }
}

