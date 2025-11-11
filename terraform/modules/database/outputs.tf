output "security_group_id" {
  description = "Security group ID for the database"
  value       = aws_security_group.db.id
}

output "instance_id" {
  description = "Database instance ID"
  value       = aws_instance.db.id
}

output "private_ip" {
  description = "Private IP of the database instance"
  value       = aws_instance.db.private_ip
}

output "data_volume_id" {
  description = "ID of the attached data volume"
  value       = aws_ebs_volume.data.id
}

output "connection_string" {
  description = "Connection string for the database"
  value       = "postgres://${var.db_username}:${var.db_password}@${aws_instance.db.private_ip}:5432/playlistparser"
  sensitive   = true
}

output "backup_plan_id" {
  description = "ID of the backup plan"
  value       = aws_backup_plan.this.id
}
