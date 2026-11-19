mock_provider "aws" {}

variables {
  name              = "test"
  vpc_id            = "vpc-12345678"
  vpc_cidr_block    = "10.20.0.0/16"
  public_subnet_ids = ["subnet-aaaa1111", "subnet-bbbb2222"]
}

run "http_only_without_a_certificate" {
  command = plan

  assert {
    condition     = length(aws_lb_listener.https) == 0
    error_message = "No certificate means no HTTPS listener."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.web) == 1
    error_message = "Only port 80 should be open without a certificate."
  }
}

run "https_and_redirect_with_a_certificate" {
  command = plan

  variables {
    certificate_arn = "arn:aws:acm:ap-south-1:111122223333:certificate/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = length(aws_lb_listener.https) == 1
    error_message = "A certificate must create the HTTPS listener."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.web) == 2
    error_message = "Ports 80 and 443 should be open when HTTPS is on."
  }
}

run "invalid_headers_are_dropped" {
  command = plan

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "The load balancer must drop invalid HTTP headers."
  }
}
