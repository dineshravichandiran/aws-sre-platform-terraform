provider "aws" {
  region = var.region

  # Every resource gets these tags automatically. They are what the AWS Budget
  # and Cost Explorer group by.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "${var.project}-${var.environment}"
  azs  = var.availability_zones

  # /16 -> /24 slices: 10.20.0.0/24 and .1.0/24 public, .10.0/24 and .11.0/24 private.
  public_subnet_cidrs  = [for i in range(2) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs = [for i in range(2) : cidrsubnet(var.vpc_cidr, 8, i + 10)]

  db_port = 5432
}

module "vpc" {
  source = "../../modules/vpc"

  name                 = local.name
  cidr_block           = var.vpc_cidr
  azs                  = local.azs
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

module "alb" {
  source = "../../modules/alb"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  vpc_cidr_block        = module.vpc.vpc_cidr_block
  public_subnet_ids     = module.vpc.public_subnet_ids
  target_port           = var.container_port
  certificate_arn       = var.certificate_arn
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
}

module "ecs" {
  source = "../../modules/ecs-service"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  vpc_cidr_block        = module.vpc.vpc_cidr_block
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn
  image                 = var.container_image
  container_port        = var.container_port

  egress_vpc_ports = var.enable_rds ? [local.db_port] : []

  # The app learns where the database is and which secret holds its password.
  # The password itself is injected by ECS at start-up and never passes through Terraform.
  environment = var.enable_rds ? { DB_ENDPOINT = module.rds[0].endpoint } : {}
  secrets     = var.enable_rds ? { DB_CREDENTIALS = module.rds[0].master_secret_arn } : {}
}

module "slo" {
  source = "../../modules/slo"

  name                    = local.name
  alb_arn_suffix          = module.alb.arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  slo_target              = var.slo_target
  alarm_email             = var.alarm_email
}

module "rds" {
  count  = var.enable_rds ? 1 : 0
  source = "../../modules/rds"

  name                      = local.name
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  client_security_group_ids = [module.ecs.security_group_id]
}
