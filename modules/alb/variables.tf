variable "name" {
  description = "Name prefix for the load balancer, target group and security group."
  type        = string
}

variable "vpc_id" {
  description = "VPC the load balancer lives in."
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR. The load balancer may only send traffic to targets inside it."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the load balancer (at least two zones)."
  type        = list(string)
}

variable "target_port" {
  description = "Port the ECS tasks listen on."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "HTTP path the target group probes."
  type        = string
  default     = "/"
}

variable "certificate_arn" {
  description = "ACM certificate ARN. Null = HTTP only (fine for a demo, not for production). Set = HTTPS on 443 and HTTP redirects to it."
  type        = string
  default     = null
}

variable "allowed_ingress_cidrs" {
  description = "Who may reach the load balancer. Default is the whole internet, because it is a public web entry point."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "deletion_protection" {
  description = "Block deletion of the load balancer. Leave false for a demo you intend to destroy."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags added to every resource."
  type        = map(string)
  default     = {}
}
