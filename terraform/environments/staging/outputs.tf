output "environment" {
  description = "Environment name"
  value       = var.environment_name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = var.vpc_cidr
}

output "database_private_ip" {
  description = "Private IP of the database"
  value       = module.database.private_ip
}

output "database_connection_string" {
  description = "Connection string for the database"
  value       = module.database.connection_string
  sensitive   = true
}

output "frontend_instance_ids" {
  description = "Frontend instance IDs"
  value       = module.compute.frontend_instance_ids
}

output "api_instance_ids" {
  description = "API instance IDs"
  value       = module.compute.api_instance_ids
}

output "database_instance_id" {
  description = "Database instance ID"
  value       = module.database.instance_id
}

output "backup_plan_id" {
  description = "Backup plan ID"
  value       = module.database.backup_plan_id
}
