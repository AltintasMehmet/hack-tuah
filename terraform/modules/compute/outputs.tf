output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = aws_security_group.alb.id
}

output "frontend_security_group_id" {
  description = "Security group ID of the frontend tier"
  value       = aws_security_group.frontend.id
}

output "api_security_group_id" {
  description = "Security group ID of the API tier"
  value       = aws_security_group.api.id
}

output "frontend_autoscaling_group_name" {
  description = "Name of the frontend autoscaling group"
  value       = aws_autoscaling_group.frontend.name
}

output "api_autoscaling_group_name" {
  description = "Name of the API autoscaling group"
  value       = aws_autoscaling_group.api.name
}

output "frontend_instance_ids" {
  description = "Instance IDs launched by the frontend autoscaling group"
  value       = aws_autoscaling_group.frontend.instances
}

output "api_instance_ids" {
  description = "Instance IDs launched by the API autoscaling group"
  value       = aws_autoscaling_group.api.instances
}
