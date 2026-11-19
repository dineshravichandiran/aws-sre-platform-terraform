# Plan-only tests with a mocked provider: no AWS account, no credentials, no cost.

mock_provider "aws" {
  # The mock returns random text for JSON fields; IAM needs real JSON.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name                 = "test"
  azs                  = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
  private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
}

run "one_shared_nat_by_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Default is one shared NAT gateway."
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Expect one public and one private subnet per zone."
  }
}

run "nat_per_zone_when_asked" {
  command = plan

  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "single_nat_gateway = false must create one NAT gateway per zone."
  }
}

run "public_subnets_do_not_auto_assign_public_ips" {
  command = plan

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch == false])
    error_message = "Public subnets must not hand out public IPs automatically."
  }
}

run "rejects_a_single_zone" {
  command = plan

  variables {
    azs                  = ["ap-south-1a"]
    public_subnet_cidrs  = ["10.20.0.0/24"]
    private_subnet_cidrs = ["10.20.10.0/24"]
  }

  expect_failures = [var.azs]
}
