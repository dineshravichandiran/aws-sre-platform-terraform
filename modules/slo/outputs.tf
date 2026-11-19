output "sns_topic_arn" {
  description = "Topic that receives the SLO alerts. Subscribe a pager or chat tool to it."
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "CloudWatch dashboard showing the SLIs against the objectives."
  value       = aws_cloudwatch_dashboard.slo.dashboard_name
}

output "error_budget_fraction" {
  description = "Allowed failure fraction, for example 0.001 for a 99.9% objective."
  value       = local.error_budget
}

output "error_budget_minutes_per_30_days" {
  description = "How many minutes of total outage a 30-day window can absorb."
  value       = local.error_budget * 30 * 24 * 60
}
