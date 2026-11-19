variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name, used as a prefix and in the IAM role names."
  type        = string
  default     = "sre-platform"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the roles, as owner/name."
  type        = string
  default     = "dineshravichandiran/aws-sre-platform-terraform"
}

variable "github_environment" {
  description = "GitHub environment whose jobs may assume the apply role. Protect it with a required reviewer."
  type        = string
  default     = "dev"
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if this AWS account already has one (only one is allowed per account)."
  type        = bool
  default     = true
}

variable "budget_email" {
  description = "Email that receives the budget alerts."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly cost limit that triggers the alerts."
  type        = number
  default     = 25
}

variable "owner" {
  description = "Value of the Owner tag."
  type        = string
  default     = "dineshravichandiran"
}
