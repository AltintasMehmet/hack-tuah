variable "environment_name" {
  description = "Name of the environment"
  type        = string
  default     = "staging"
}

variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
}

variable "app_repository" {
  description = "Git repository URL containing the Playlist Parser application"
  type        = string
}

variable "spotify_client_id" {
  description = "Spotify OAuth client ID"
  type        = string
}

variable "spotify_client_secret" {
  description = "Spotify OAuth client secret"
  type        = string
  sensitive   = true
}

variable "spotify_redirect_uri" {
  description = "Spotify redirect URI for this environment"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "playlistparser"
}

variable "frontend_ami" {
  description = "AMI ID for the frontend instances"
  type        = string
}

variable "api_ami" {
  description = "AMI ID for the API instances"
  type        = string
}

variable "database_ami" {
  description = "AMI ID for the database instance"
  type        = string
}

variable "frontend_instance_type" {
  description = "Instance type for the frontend tier"
  type        = string
  default     = "t3.micro"
}

variable "api_instance_type" {
  description = "Instance type for the API tier"
  type        = string
  default     = "t3.micro"
}

variable "database_instance_type" {
  description = "Instance type for the database tier"
  type        = string
  default     = "t3.small"
}

variable "frontend_desired_capacity" {
  description = "Number of frontend instances"
  type        = number
  default     = 1
}

variable "api_desired_capacity" {
  description = "Number of API instances"
  type        = number
  default     = 1
}

variable "database_volume_size" {
  description = "Size of the database EBS volume"
  type        = number
  default     = 50
}

variable "database_volume_type" {
  description = "Type of the database EBS volume"
  type        = string
  default     = "gp3"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones to deploy subnets"
  type        = list(string)
}

variable "frontend_port" {
  description = "Port used by the frontend"
  type        = number
  default     = 80
}

variable "api_port" {
  description = "Port exposed by the API"
  type        = number
  default     = 3000
}

variable "alb_listener_port" {
  description = "Port exposed by the ALB"
  type        = number
  default     = 80
}

variable "alb_idle_timeout" {
  description = "Idle timeout for the ALB"
  type        = number
  default     = 60
}

variable "ssh_key_name" {
  description = "Optional SSH key pair name for the instances"
  type        = string
  default     = null
}

variable "frontend_additional_environment_variables" {
  description = "Additional environment variables for the frontend"
  type        = map(string)
  default     = {}
}

variable "api_additional_environment_variables" {
  description = "Additional environment variables for the API"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to resources"
  type        = map(string)
  default     = {}
}
