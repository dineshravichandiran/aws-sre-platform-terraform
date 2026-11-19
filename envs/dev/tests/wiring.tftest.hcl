# Plans the whole environment against a mocked AWS provider.
# This proves the modules are wired together correctly. It does not prove anything about a real account.

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      endpoint = "demo.abcdefghijkl.ap-south-1.rds.amazonaws.com:5432"
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:ap-south-1:111122223333:secret:rds!db-00000000-0000-0000-0000-000000000000-AbCdEf"
        kms_key_id    = "alias/aws/secretsmanager"
        secret_status = "active"
      }]
    }
  }
}

run "default_environment_plans" {
  command = plan

  assert {
    condition     = length(module.rds) == 1
    error_message = "The database is on by default."
  }

  assert {
    condition     = module.vpc.nat_gateway_count == 1
    error_message = "One shared NAT gateway by default."
  }

  assert {
    condition     = abs(module.slo.error_budget_fraction - 0.001) < 0.0000001
    error_message = "The SLO module is wired in with a 99.9% objective."
  }
}

run "database_can_be_turned_off" {
  command = plan

  variables {
    enable_rds = false
  }

  assert {
    condition     = length(module.rds) == 0
    error_message = "enable_rds = false must remove the database."
  }
}

run "needs_exactly_two_zones" {
  command = plan

  variables {
    availability_zones = ["ap-south-1a"]
  }

  expect_failures = [var.availability_zones]
}
