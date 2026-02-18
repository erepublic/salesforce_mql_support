output "rest_api_id" {
  value       = aws_api_gateway_rest_api.sandbox.id
  description = "Sandbox API Gateway REST API id."
}

output "sandbox_invoke_url" {
  value       = "https://${aws_api_gateway_rest_api.sandbox.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.sandbox.stage_name}/summarize"
  description = "Sandbox invoke URL."
}

output "production_invoke_url" {
  value       = "https://${aws_api_gateway_rest_api.production.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.production.stage_name}/summarize"
  description = "Production invoke URL."
}

output "production_rest_api_id" {
  value       = aws_api_gateway_rest_api.production.id
  description = "Production API Gateway REST API id."
}

