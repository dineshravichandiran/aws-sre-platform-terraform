variable "region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "availability_zones" {
  description = "Two zones to spread over. Pinned by name so a new zone appearing in the region never changes the plan."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Give exactly two availability zones: the subnet layout is built for two."
  }
}

variable "project" {
  description = "Project name, used as a prefix on every resource."
  type        = string
  default     = "sre-platform"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Subnets are carved out of it."
  type        = string
  default     = "10.20.0.0/16"
}

variable "single_nat_gateway" {
  description = "One shared NAT gateway (cheap) or one per zone (resilient)."
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Null serves plain HTTP, which is fine for a short demo only."
  type        = string
  default     = null
}

variable "allowed_ingress_cidrs" {
  description = "Who may reach the load balancer. Narrow this to your own IP while you test."
  type        = list(string)
  default     = ["103.241.80.138/32"]
}

variable "container_image" {
  description = "Image the ECS service runs."
  type        = string
  default     = "public.ecr.aws/nginx/nginx-unprivileged:stable"
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}

variable "enable_rds" {
  description = "Create the PostgreSQL database. Turn off to cut the demo cost further."
  type        = bool
  default     = true
}

variable "slo_target" {
  description = "Availability objective for the service, as a fraction (0.999 = 99.9%)."
  type        = number
  default     = 0.999
}

variable "alarm_email" {
  description = "Email that receives SLO alerts. Null creates the alert topic with no subscriber."
  type        = string
  default     = null
}

variable "owner" {
  description = "Value of the Owner cost-allocation tag."
  type        = string
  default     = "dineshravichandiran"
}
