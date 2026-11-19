variable "name" {
  description = "Name prefix for every resource in this VPC."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr_block))
    error_message = "cidr_block must be a valid IPv4 CIDR, for example 10.20.0.0/16."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets over. One public and one private subnet per zone."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "Use at least two availability zones so the ALB and the database subnet group are valid."
  }
}

variable "public_subnet_cidrs" {
  description = "One CIDR per availability zone, for the public subnets (ALB, NAT gateway)."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "One CIDR per availability zone, for the private subnets (ECS tasks, RDS)."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheap, one point of failure). false = one NAT gateway per zone."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "How long VPC flow logs are kept in CloudWatch Logs."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Extra tags added to every resource."
  type        = map(string)
  default     = {}
}
