variable "name" {
  description = "Name prefix for the cluster, service, roles and log group."
  type        = string
}

variable "vpc_id" {
  description = "VPC the tasks run in."
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR, used to scope optional egress to other private services such as the database."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the tasks. Tasks get no public IP."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group of the load balancer. It is the only source allowed to reach the tasks."
  type        = string
}

variable "target_group_arn" {
  description = "Target group the service registers its tasks into."
  type        = string
}

variable "image" {
  description = "Container image to run. Default is an unprivileged nginx from the public ECR gallery, so the demo needs no build step."
  type        = string
  default     = "public.ecr.aws/nginx/nginx-unprivileged:stable"
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Starting number of tasks. Autoscaling changes it after that."
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Autoscaling floor."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Autoscaling ceiling."
  type        = number
  default     = 4
}

variable "cpu_target_percent" {
  description = "Average CPU the autoscaler tries to hold."
  type        = number
  default     = 60
}

variable "environment" {
  description = "Plain environment variables for the container. Do not put secrets here."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Container secrets as name => Secrets Manager or SSM parameter ARN. The execution role is allowed to read exactly these."
  type        = map(string)
  default     = {}
}

variable "egress_vpc_ports" {
  description = "Ports the tasks may reach inside the VPC, for example 5432 for the database."
  type        = list(number)
  default     = []
}

variable "log_retention_days" {
  description = "How long container logs are kept."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Extra tags added to every resource."
  type        = map(string)
  default     = {}
}
