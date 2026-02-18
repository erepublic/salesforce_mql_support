output "region" {
  value       = var.region
  description = "AWS region for the Terraform state backend."
}

output "state_bucket_name" {
  value       = aws_s3_bucket.tf_state.bucket
  description = "S3 bucket name to use for Terraform remote state."
}

output "lock_table_name" {
  value       = aws_dynamodb_table.tf_lock.name
  description = "DynamoDB table name to use for Terraform state locking."
}

