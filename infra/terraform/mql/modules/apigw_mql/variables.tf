variable "name_prefix" {
  type        = string
  description = "Naming prefix."
}

variable "region" {
  type        = string
  description = "AWS region for constructing invoke URLs."
}

variable "tags" {
  type        = map(string)
  description = "Tags for resources."
  default     = {}
}

variable "sandbox_lambda_invoke_arn" {
  type        = string
  description = "Invoke ARN for sandbox Lambda."
}

variable "production_lambda_invoke_arn" {
  type        = string
  description = "Invoke ARN for production Lambda."
}

variable "sandbox_lambda_function_name" {
  type        = string
  description = "Sandbox Lambda function name (for permissions)."
}

variable "production_lambda_function_name" {
  type        = string
  description = "Production Lambda function name (for permissions)."
}

variable "sandbox_api_key_value" {
  type        = string
  description = "API key value for sandbox."
  sensitive   = true
}

variable "production_api_key_value" {
  type        = string
  description = "API key value for production."
  sensitive   = true
}

