output "bucket_name" {
  description = "Terraform state bucket name"
  value       = aws_s3_bucket.state.bucket
}

output "dynamodb_table_name" {
  description = "Terraform state DynamoDB table name"
  value       = aws_dynamodb_table.locks.name
}
