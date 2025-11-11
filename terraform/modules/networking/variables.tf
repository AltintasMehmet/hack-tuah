variable "name" {
  description = "Base name for networking resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. staging or production)"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnets must be specified."
  }
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnets must be specified."
  }
}

variable "availability_zones" {
  description = "List of availability zones that match the provided subnet CIDRs"
  type        = list(string)
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}
