# S3 Module with ABAC

Terraform module that provisions a secure S3 bucket with optional Attribute-Based Access Control (ABAC) using principal tags and object tags. Designed to leverage the recent S3 data-plane ABAC capabilities so principals only access objects whose tags match their session tags.

## Features

- Secure bucket defaults: bucket-owner enforced ACLs (configurable), public access block (configurable), SSE-S3 or KMS.
- Optional versioning and force-destroy toggle; expected bucket owner guard.
- Lifecycle rules, CORS, replication, inventory, metrics, analytics, intelligent tiering.
- Website hosting, notifications (SNS/SQS/Lambda), transfer acceleration.
- S3 Access Grants (instance/location/grants), Object Lambda access points, S3 Express directory bucket.
- ABAC policy that:
  - Denies untagged principals.
  - Allows list/object access only when `aws:PrincipalTag/<key>` matches the bucket/object tag.
  - Denies writes that do not set the required object tag.

## Usage

```hcl
provider "aws" {
  region = "us-east-1"
}

module "abac_bucket" {
  source = "../" # replace with your module source

  bucket_name           = "my-abac-bucket-example"
  abac_tag_key          = "project"
  abac_bucket_tag_value = "data-analytics"
  abac_principals = [
    "arn:aws:iam::123456789012:role/abac-analytics-role"
  ]

  tags = {
    env = "dev"
  }
}
```

Additional examples live in `examples/`:

- `examples/full`: lifecycle + CORS + replication + intelligent tiering + inventory/metrics/analytics + notifications + website + acceleration.
- `examples/access-grants-object-lambda`: Access Grants instance/location/grant, directory bucket, Object Lambda AP (ABAC disabled).
- `examples/abac`: minimal ABAC bucket.
- `examples/sec-dom`: ABAC using company tag key `sec-dom` with value `payments`.

To test ABAC, assume an IAM role with a matching session tag:

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/abac-analytics-role \
  --role-session-name abac-test \
  --tags "project=data-analytics"
```

Uploads must include the tag key/value so they match the caller’s `aws:PrincipalTag/project`, e.g. with AWS CLI:

```bash
aws s3api put-object \
  --bucket my-abac-bucket-example \
  --key demo.txt \
  --body ./demo.txt \
  --tagging "project=data-analytics"
```

## Inputs

- `bucket_name` (string, required): Bucket name.
- `object_ownership` (string, default `BucketOwnerEnforced`).
- `force_destroy` (bool, default `false`): Allow destroy with objects.
- `enable_versioning` (bool, default `true`): Enable versioning.
- `kms_key_id` (string, default `null`): KMS key for SSE.
- `block_public_acls|block_public_policy|ignore_public_acls|restrict_public_buckets` (bools): Public access protections.
- `create_public_access_block` (bool, default `true`).
- `tags` (map): Extra tags.
- `enable_abac` (bool, default `true`): Toggle ABAC policy.
- `abac_tag_key` (string): Tag key used for principal/object match.
- `abac_bucket_tag_value` (string, default `abac-enabled`): Bucket tag value used for list checks.
- `abac_principals` (set(string)): IAM principal ARNs allowed via ABAC.
- `abac_object_actions` (list(string)): Object actions permitted when tags match.
- `expected_bucket_owner` (string, default `null`): Policy safety check.
- `lifecycle_rules` (list): Lifecycle rules.
- `cors_rules` (list): CORS configuration.
- `replication_configuration` (object): Replication role and rules.
- `intelligent_tiering_configurations` (list): Intelligent tiering configs.
- `inventory_configurations` (list): Inventory definitions.
- `metric_configuration` (list): Bucket metric configs.
- `analytics_configuration` (list): Analytics configs.
- `website` (object): Website hosting (index/error/redirect/routing rules).
- `notifications` (object): SNS/SQS/Lambda event destinations.
- `enable_transfer_acceleration` (bool): Transfer acceleration toggle.
- `directory_bucket` (object): S3 Express directory bucket config.
- `access_grants` (object): S3 Access Grants instance/location/grants.
- `object_lambda_access_points` (list): Object Lambda access points.

## Outputs

- `bucket_id`, `bucket_arn`, `bucket_domain_name`, `bucket_regional_domain_name`, `bucket_policy_id`.
- `dualstack_endpoint`, `website_endpoint`, `access_grants_instance_arn`, `directory_bucket_arn`.

## Notes on the S3 ABAC feature

S3 now supports enforcing data-plane access based on tags. This module’s policy:

- Requires principals to present `aws:PrincipalTag/<abac_tag_key>`.
- Matches that value against the bucket tag for `ListBucket`.
- Matches against `s3:ExistingObjectTag/<abac_tag_key>` for object reads/writes.
- Denies writes when `s3:RequestObjectTag/<abac_tag_key>` is missing or mismatched.

Ensure your IAM roles allow session tags for the chosen `abac_tag_key`. Without session tags, access is denied.