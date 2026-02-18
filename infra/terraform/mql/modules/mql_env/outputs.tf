output "lambda_function_name" {
  value       = aws_lambda_function.lambda.function_name
  description = "Lambda function name."
}

output "lambda_invoke_arn" {
  value       = aws_lambda_function.lambda.invoke_arn
  description = "Lambda invoke ARN (for API Gateway integration)."
}

output "idempotency_table_name" {
  value       = aws_dynamodb_table.idempotency.name
  description = "DynamoDB idempotency table name."
}

output "dlq_arn" {
  value       = aws_sqs_queue.dlq.arn
  description = "DLQ ARN."
}

output "salesforce_secret_arn" {
  value       = aws_secretsmanager_secret.salesforce.arn
  description = "Secrets Manager secret ARN for Salesforce credentials/config."
}

output "hubspot_secret_arn" {
  value       = aws_secretsmanager_secret.hubspot.arn
  description = "Secrets Manager secret ARN for HubSpot token/config."
}

output "openai_secret_arn" {
  value       = aws_secretsmanager_secret.openai.arn
  description = "Secrets Manager secret ARN for OpenAI API key/model config."
}

