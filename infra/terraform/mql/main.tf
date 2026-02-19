provider "aws" {
  region = var.region
}

locals {
  lambda_private_subnets = {
    for idx, az in var.lambda_private_subnet_azs :
    az => { az = az, cidr = var.lambda_private_subnet_cidrs[idx] }
  }
}

resource "aws_security_group" "lambda_vpc" {
  name_prefix = "${var.name_prefix}-lambda-egress-"
  description = "Lambda security group (egress via NAT)."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-lambda-egress" })
}

resource "aws_subnet" "lambda_private" {
  for_each = local.lambda_private_subnets

  vpc_id                  = var.vpc_id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.name_prefix}-lambda-private-${each.key}" })
}

resource "aws_eip" "lambda_nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-lambda-nat-eip" })
}

resource "aws_nat_gateway" "lambda" {
  allocation_id = aws_eip.lambda_nat.id
  subnet_id     = var.nat_gateway_public_subnet_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-lambda-nat" })
}

resource "aws_route_table" "lambda_private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.lambda.id
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-lambda-private-rt" })
}

resource "aws_route_table_association" "lambda_private" {
  for_each = aws_subnet.lambda_private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.lambda_private.id
}

resource "aws_security_group_rule" "redshift_from_lambda_nat" {
  type              = "ingress"
  security_group_id = var.redshift_security_group_id

  protocol    = "tcp"
  from_port   = 5439
  to_port     = 5439
  cidr_blocks = ["${aws_eip.lambda_nat.public_ip}/32"]

  description = "Allow Lambda NAT egress IP to reach Redshift (5439)."
}

resource "aws_security_group_rule" "redshift_from_lambda_sg" {
  type                     = "ingress"
  security_group_id        = var.redshift_security_group_id
  source_security_group_id = aws_security_group.lambda_vpc.id

  protocol  = "tcp"
  from_port = 5439
  to_port   = 5439

  description = "Allow Lambda SG to reach Redshift (5439) within VPC."
}

resource "random_password" "sandbox_api_key" {
  length  = 32
  special = false
}

resource "random_password" "production_api_key" {
  length  = 32
  special = false
}

locals {
  envs = {
    sandbox = {
      name    = "sandbox"
      src_dir = abspath(var.lambda_src_dir_sandbox)
      api_key = coalesce(var.api_key_value_sandbox, random_password.sandbox_api_key.result)
    }
    production = {
      name    = "production"
      src_dir = abspath(var.lambda_src_dir_production)
      api_key = coalesce(var.api_key_value_production, random_password.production_api_key.result)
    }
  }
}

module "mql_env" {
  for_each = local.envs
  source   = "./modules/mql_env"

  region               = var.region
  name_prefix          = var.name_prefix
  env_name             = each.value.name
  tags                 = var.tags
  log_retention_days   = var.log_retention_days
  idempotency_ttl_attr = var.idempotency_ttl_attribute

  lambda_src_dir         = each.value.src_dir
  lambda_runtime         = var.lambda_runtime
  lambda_handler         = var.lambda_handler
  lambda_memory_mb       = var.lambda_memory_mb
  lambda_timeout_seconds = var.lambda_timeout_seconds

  lambda_vpc_subnet_ids = [
    for az in var.lambda_private_subnet_azs : aws_subnet.lambda_private[az].id
  ]
  lambda_vpc_security_group_ids = [aws_security_group.lambda_vpc.id]
}

module "apigw_mql" {
  source = "./modules/apigw_mql"

  name_prefix = var.name_prefix
  region      = var.region
  tags        = var.tags

  sandbox_lambda_invoke_arn    = module.mql_env["sandbox"].lambda_invoke_arn
  production_lambda_invoke_arn = module.mql_env["production"].lambda_invoke_arn

  sandbox_lambda_function_name    = module.mql_env["sandbox"].lambda_function_name
  production_lambda_function_name = module.mql_env["production"].lambda_function_name

  sandbox_api_key_value    = local.envs.sandbox.api_key
  production_api_key_value = local.envs.production.api_key
}

