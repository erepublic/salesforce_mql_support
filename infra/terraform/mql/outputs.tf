output "region" {
  value       = var.region
  description = "AWS region for the MQL stack."
}

output "sandbox_invoke_url" {
  value       = module.apigw_mql.sandbox_invoke_url
  description = "Invoke URL for sandbox webhook: <base>/sandbox/summarize"
}

output "production_invoke_url" {
  value       = module.apigw_mql.production_invoke_url
  description = "Invoke URL for production webhook: <base>/production/summarize"
}

output "sandbox_api_gateway_id" {
  value       = module.apigw_mql.rest_api_id
  description = "Sandbox API Gateway REST API id."
}

output "production_api_gateway_id" {
  value       = module.apigw_mql.production_rest_api_id
  description = "Production API Gateway REST API id."
}

output "sandbox_lambda_name" {
  value       = module.mql_env["sandbox"].lambda_function_name
  description = "Sandbox lambda function name."
}

output "production_lambda_name" {
  value       = module.mql_env["production"].lambda_function_name
  description = "Production lambda function name."
}

output "sandbox_openai_secret_arn" {
  value       = module.mql_env["sandbox"].openai_secret_arn
  description = "Sandbox secret ARN for OpenAI config."
}

output "production_openai_secret_arn" {
  value       = module.mql_env["production"].openai_secret_arn
  description = "Production secret ARN for OpenAI config."
}

output "sandbox_api_key_value" {
  value       = coalesce(var.api_key_value_sandbox, random_password.sandbox_api_key.result)
  description = "Sandbox API Gateway API key value to send as x-api-key."
  sensitive   = true
}

output "production_api_key_value" {
  value       = coalesce(var.api_key_value_production, random_password.production_api_key.result)
  description = "Production API Gateway API key value to send as x-api-key."
  sensitive   = true
}

