variable "region" {
  type        = string
  description = "AWS region."
}

variable "name_prefix" {
  type        = string
  description = "Naming prefix."
}

variable "env_name" {
  type        = string
  description = "Environment name (sandbox|production)."
}

variable "tags" {
  type        = map(string)
  description = "Tags for all resources."
  default     = {}
}

variable "lambda_src_dir" {
  type        = string
  description = "Local directory to package into the Lambda zip."
}

variable "lambda_runtime" {
  type        = string
  description = "Lambda runtime."
}

variable "lambda_handler" {
  type        = string
  description = "Lambda handler."
}

variable "lambda_memory_mb" {
  type        = number
  description = "Lambda memory."
}

variable "lambda_timeout_seconds" {
  type        = number
  description = "Lambda timeout."
}

variable "log_retention_days" {
  type        = number
  description = "Log retention days."
}

variable "idempotency_ttl_attr" {
  type        = string
  description = "DynamoDB TTL attribute name."
}

