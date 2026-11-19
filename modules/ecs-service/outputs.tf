output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "security_group_id" {
  description = "Security group of the tasks. The database allows traffic from this group."
  value       = aws_security_group.tasks.id
}

output "log_group_name" {
  description = "CloudWatch log group holding the container logs."
  value       = aws_cloudwatch_log_group.this.name
}

output "task_role_name" {
  description = "Role the application code runs as. Attach app permissions here."
  value       = aws_iam_role.task.name
}
