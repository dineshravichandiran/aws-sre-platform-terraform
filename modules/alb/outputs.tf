output "dns_name" {
  description = "Public DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "arn_suffix" {
  description = "Load balancer ARN suffix, used as a CloudWatch metric dimension."
  value       = aws_lb.this.arn_suffix
}

output "security_group_id" {
  description = "Security group of the load balancer. Targets allow traffic from this group."
  value       = aws_security_group.this.id
}

output "target_group_arn" {
  description = "Target group the ECS service registers into."
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix, used as a CloudWatch metric dimension."
  value       = aws_lb_target_group.this.arn_suffix
}
