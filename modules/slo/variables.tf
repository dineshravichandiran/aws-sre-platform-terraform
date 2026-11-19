variable "name" {
  description = "Name prefix for alarms, topic and dashboard."
  type        = string
}

variable "alb_arn_suffix" {
  description = "Load balancer ARN suffix (the part after loadbalancer/). The alb module outputs it."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix. The alb module outputs it."
  type        = string
}

variable "slo_target" {
  description = "Availability objective as a fraction, for example 0.999 for 99.9%."
  type        = number
  default     = 0.999

  validation {
    condition     = var.slo_target > 0.9 && var.slo_target < 1
    error_message = "slo_target must be between 0.9 and 1 (exclusive), for example 0.999."
  }
}

variable "latency_slo_seconds" {
  description = "p99 response time the service should stay under."
  type        = number
  default     = 1
}

variable "alarm_email" {
  description = "Email subscribed to the alert topic. Null creates the topic with no subscriber."
  type        = string
  default     = null
}

variable "tags" {
  description = "Extra tags added to every resource."
  type        = map(string)
  default     = {}
}
