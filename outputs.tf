output "bucket_id" {
  description = "Bucket name."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Bucket ARN."
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional bucket domain name."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_policy_id" {
  description = "Bucket policy ID when ABAC is enabled."
  value       = try(aws_s3_bucket_policy.abac[0].id, null)
}

output "dualstack_endpoint" {
  description = "Dualstack endpoint for the bucket."
  value       = format("https://%s", replace(aws_s3_bucket.this.bucket_regional_domain_name, "s3.", "s3.dualstack."))
}

output "website_endpoint" {
  description = "Website endpoint when website hosting is configured."
  value       = try(aws_s3_bucket_website_configuration.this[0].website_endpoint, null)
}

output "access_grants_instance_arn" {
  description = "ARN of the S3 Access Grants instance."
  value       = try(aws_s3control_access_grants_instance.this[0].access_grants_instance_arn, null)
}

output "directory_bucket_arn" {
  description = "ARN of the S3 Directory bucket (if created)."
  value       = try(aws_s3_directory_bucket.this[0].arn, null)
}

