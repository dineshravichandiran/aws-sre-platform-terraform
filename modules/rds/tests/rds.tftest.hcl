mock_provider "aws" {}

variables {
  name                      = "test"
  vpc_id                    = "vpc-12345678"
  private_subnet_ids        = ["subnet-aaaa1111", "subnet-bbbb2222"]
  client_security_group_ids = ["sg-12345678"]
}

run "database_is_private_and_encrypted" {
  command = plan

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false && aws_db_instance.this.storage_encrypted == true
    error_message = "The database must be private and encrypted at rest."
  }
}

run "password_is_never_in_the_code" {
  command = plan

  assert {
    condition     = aws_db_instance.this.manage_master_user_password == true
    error_message = "RDS must manage the admin password in Secrets Manager."
  }
}

run "one_ingress_rule_per_client" {
  command = plan

  variables {
    client_security_group_ids = ["sg-11111111", "sg-22222222"]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_clients) == 2
    error_message = "Expect one ingress rule per client security group."
  }
}

run "final_snapshot_when_not_skipped" {
  command = plan

  variables {
    skip_final_snapshot = false
  }

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == "test-final"
    error_message = "Keeping the final snapshot needs an identifier."
  }
}
