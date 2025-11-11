variable "name" {
  description = "Base name for compute resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs used by the load balancer"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the application instances"
  type        = list(string)
}

variable "alb_idle_timeout" {
  description = "Idle timeout for the Application Load Balancer"
  type        = number
  default     = 60
}

variable "frontend_port" {
  description = "Port where the frontend service listens"
  type        = number
  default     = 80
}

variable "api_port" {
  description = "Port where the API service listens"
  type        = number
  default     = 3000
}

variable "alb_listener_port" {
  description = "Port exposed by the ALB"
  type        = number
  default     = 80
}

variable "frontend_launch_template" {
  description = "Configuration for the frontend launch template"
  type = object({
    ami_id                    = string
    instance_type             = string
    desired_capacity          = number
    min_size                  = number
    max_size                  = number
    key_name                  = optional(string)
    enable_cloudwatch_agent   = optional(bool, true)
    environment_variables     = map(string)
  })
}

variable "api_launch_template" {
  description = "Configuration for the API launch template"
  type = object({
    ami_id                    = string
    instance_type             = string
    desired_capacity          = number
    min_size                  = number
    max_size                  = number
    key_name                  = optional(string)
    enable_cloudwatch_agent   = optional(bool, true)
    environment_variables     = map(string)
  })
}

variable "tags" {
  description = "Tags to apply to compute resources"
  type        = map(string)
  default     = {}
}
