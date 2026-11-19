output "endpoint" {
  description = "Database host and port."
  value       = aws_db_instance.this.endpoint
}

output "security_group_id" {
  description = "Security group of the database."
  value       = aws_security_group.this.id
}

output "master_secret_arn" {
  description = "Secrets Manager ARN of the admin credentials that RDS generated."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
