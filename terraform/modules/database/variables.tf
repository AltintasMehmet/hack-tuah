variable "name" {
  description = "Base name for database resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the database instance"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the database instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the database"
  type        = string
}

variable "volume_size" {
  description = "Size of the data volume in GiB"
  type        = number
  default     = 50
}

variable "volume_type" {
  description = "Type of the data volume"
  type        = string
  default     = "gp3"
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
}

variable "enable_cloudwatch_agent" {
  description = "Whether to install the CloudWatch agent"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
