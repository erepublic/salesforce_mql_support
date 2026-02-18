provider "aws" {
  region = var.region
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

