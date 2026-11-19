mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name                  = "test"
  vpc_id                = "vpc-12345678"
  vpc_cidr_block        = "10.20.0.0/16"
  private_subnet_ids    = ["subnet-aaaa1111", "subnet-bbbb2222"]
  alb_security_group_id = "sg-12345678"
  target_group_arn      = "arn:aws:elasticloadbalancing:ap-south-1:111122223333:targetgroup/app/0123456789abcdef"
}

run "tasks_are_private" {
  command = plan

  assert {
    condition     = aws_ecs_service.this.network_configuration[0].assign_public_ip == false
    error_message = "Tasks must not get public IPs."
  }
}

run "bad_releases_roll_back" {
  command = plan

  assert {
    condition     = aws_ecs_service.this.deployment_circuit_breaker[0].rollback == true
    error_message = "The deployment circuit breaker must roll back a failing release."
  }
}

run "no_secret_policy_without_secrets" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.read_secrets) == 0
    error_message = "No secrets listed means no secret-read policy."
  }
}

run "secret_policy_lists_exactly_the_secrets" {
  command = plan

  variables {
    secrets = {
      DB_PASSWORD = "arn:aws:secretsmanager:ap-south-1:111122223333:secret:db-AbCdEf"
    }
  }

  assert {
    condition     = length(aws_iam_role_policy.read_secrets) == 1
    error_message = "Listing a secret must create the read policy."
  }
}

run "db_egress_only_when_requested" {
  command = plan

  variables {
    egress_vpc_ports = [5432]
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.vpc_ports) == 1
    error_message = "One extra egress rule per requested port."
  }
}
