resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.private_subnet_ids

  tags = var.tags
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-db-"
  description = "Database: PostgreSQL from the listed client groups only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-db" })

  lifecycle {
    create_before_destroy = true
  }
}

# count, not for_each: the client group IDs are only known after apply, but how many there are is known now.
resource "aws_vpc_security_group_ingress_rule" "from_clients" {
  count = length(var.client_security_group_ids)

  security_group_id            = aws_security_group.this.id
  description                  = "PostgreSQL from client group ${count.index + 1}"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = var.client_security_group_ids[count.index]
}

# No egress rule: the database never starts a connection.

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_118:Enhanced monitoring needs an extra IAM role and costs a little; CloudWatch metrics and log exports are on. Listed in README as a next step.
  #checkov:skip=CKV_AWS_157:Multi-AZ is the multi_az variable and is off for the demo to halve the cost. Turn it on for production.
  #checkov:skip=CKV_AWS_293:Deletion protection is the deletion_protection variable and is off so the demo can be destroyed. Turn it on for anything real.
  #checkov:skip=CKV_AWS_353:Performance Insights support is limited on the smallest burstable classes used for the demo. Enabling it is a next step.
  #checkov:skip=CKV2_AWS_30:Query logging needs a custom parameter group; listed in README as a next step.
  identifier     = var.name
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = "dbadmin"
  # RDS creates the password and keeps it in Secrets Manager. It never appears in
  # this code, in the plan output or in a tfvars file.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  iam_database_authentication_enabled = true
  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]

  backup_retention_period   = var.backup_retention_days
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final"

  tags = var.tags
}
