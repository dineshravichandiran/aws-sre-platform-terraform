output "state_bucket" {
  description = "Put this in envs/dev/backend.hcl and in the TF_STATE_BUCKET repository variable."
  value       = aws_s3_bucket.state.id
}

output "plan_role_arn" {
  description = "Put this in the AWS_PLAN_ROLE_ARN repository variable."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Put this in the AWS_APPLY_ROLE_ARN repository variable."
  value       = aws_iam_role.apply.arn
}
