variable "name" {
  description = "Name prefix for the database, subnet group and security group."
  type        = string
}

variable "vpc_id" {
  description = "VPC the database lives in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the database subnet group (at least two zones)."
  type        = list(string)
}

variable "client_security_group_ids" {
  description = "Security groups allowed to connect, for example the ECS tasks."
  type        = list(string)
}

variable "engine_version" {
  description = "PostgreSQL major version. AWS picks the current default minor release and upgrades minors automatically."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "Instance size. db.t4g.micro is the smallest Graviton class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB."
  type        = number
  default     = 50
}

variable "database_name" {
  description = "Name of the first database."
  type        = string
  default     = "app"
}

variable "multi_az" {
  description = "Standby in a second zone. Doubles the instance cost; leave false for a demo."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Days of automated backups. Must be at least 1 to allow point-in-time restore."
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Block deletion of the database. Leave false for a demo you intend to destroy."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip the snapshot taken on destroy. true is right for a throwaway demo, false for anything real."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags added to every resource."
  type        = map(string)
  default     = {}
}
