variable "region" {
  type        = string
  description = "AWS region to deploy the MQL stack."
  default     = "us-west-1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for naming AWS resources."
  default     = "mql"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}

variable "lambda_runtime" {
  type        = string
  description = "Lambda runtime (set to match the implementation language)."
  default     = "nodejs20.x"
}

variable "lambda_handler" {
  type        = string
  description = "Lambda handler (module.function)."
  default     = "index.handler"
}

variable "lambda_memory_mb" {
  type        = number
  description = "Lambda memory size."
  default     = 1024
}

variable "lambda_timeout_seconds" {
  type        = number
  description = "Lambda timeout in seconds."
  default     = 60
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch Logs retention for Lambda log groups."
  default     = 30
}

variable "idempotency_ttl_attribute" {
  type        = string
  description = "DynamoDB TTL attribute name."
  default     = "ttlEpochSeconds"
}

variable "lambda_src_dir_sandbox" {
  type        = string
  description = "Local folder to package for the sandbox Lambda."
  default     = "lambda_src"
}

variable "lambda_src_dir_production" {
  type        = string
  description = "Local folder to package for the production Lambda."
  default     = "lambda_src"
}

variable "api_key_value_sandbox" {
  type        = string
  description = "API Gateway API key value for sandbox (sent as x-api-key)."
  sensitive   = true
  default     = null
}

variable "api_key_value_production" {
  type        = string
  description = "API Gateway API key value for production (sent as x-api-key)."
  sensitive   = true
  default     = null
}

