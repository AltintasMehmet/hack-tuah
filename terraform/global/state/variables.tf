variable "region" {
  description = "AWS region where the state resources will be created"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket to store Terraform state"
  type        = string
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
}

variable "tags" {
  description = "Tags applied to the global resources"
  type        = map(string)
  default     = {}
}
