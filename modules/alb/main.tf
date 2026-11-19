locals {
  https = var.certificate_arn != null
  ports = local.https ? [80, 443] : [80]
  # One rule per (port, cidr) pair.
  ingress = {
    for pair in setproduct(local.ports, var.allowed_ingress_cidrs) :
    "${pair[0]}-${pair[1]}" => { port = pair[0], cidr = pair[1] }
  }
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-alb-"
  description = "Load balancer: web traffic in, app traffic out to the VPC only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each = local.ingress

  security_group_id = aws_security_group.this.id
  description       = "Web traffic on ${each.value.port}"
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_egress_rule" "to_targets" {
  security_group_id = aws_security_group.this.id
  description       = "Forward to the app port inside the VPC"
  ip_protocol       = "tcp"
  from_port         = var.target_port
  to_port           = var.target_port
  cidr_ipv4         = var.vpc_cidr_block
}

resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:Access logs need a dedicated S3 bucket; left out of the demo to keep cost and scope small. Listed in README as a next step.
  #checkov:skip=CKV2_AWS_28:No WAF in front of the demo; listed in README as a next step.
  #checkov:skip=CKV_AWS_150:Deletion protection is the deletion_protection variable and is off so the demo can be destroyed. Turn it on for anything real.
  #checkov:skip=CKV2_AWS_20:The redirect exists when certificate_arn is set. Without a certificate the demo serves HTTP only.
  name                       = var.name
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.this.id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = var.deletion_protection

  tags = var.tags
}

resource "aws_lb_target_group" "this" {
  #checkov:skip=CKV_AWS_378:TLS ends at the load balancer. The hop to the task stays inside private subnets and the task security group only accepts the load balancer. End-to-end TLS is listed in README as a next step.
  name_prefix = "app-"
  port        = var.target_port
  protocol    = "HTTP"
  target_type = "ip" # Fargate tasks register by IP
  vpc_id      = var.vpc_id

  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_103:Applies to HTTPS listeners. The HTTPS listener below uses a TLS 1.3 policy; this listener only forwards or redirects.
  #checkov:skip=CKV_AWS_2:HTTP only when no certificate is supplied. Setting certificate_arn turns on HTTPS and makes this listener redirect.
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.https ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }

  dynamic "default_action" {
    for_each = local.https ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  count = local.https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = var.tags
}
