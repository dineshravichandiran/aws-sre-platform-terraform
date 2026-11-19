output "url" {
  description = "Address of the running service."
  value       = "${var.certificate_arn == null ? "http" : "https"}://${module.alb.dns_name}"
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "service_name" {
  description = "ECS service name."
  value       = module.ecs.service_name
}

output "log_group_name" {
  description = "CloudWatch log group with the container logs."
  value       = module.ecs.log_group_name
}

output "database_endpoint" {
  description = "Database host and port, or null when the database is turned off."
  value       = var.enable_rds ? module.rds[0].endpoint : null
}
