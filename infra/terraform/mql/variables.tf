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

variable "vpc_id" {
  type        = string
  description = "VPC ID for Lambda networking (should match Redshift VPC)."
  default     = "vpc-90b6fdf5"
}

variable "nat_gateway_public_subnet_id" {
  type        = string
  description = "Public subnet ID to place the NAT Gateway into."
  default     = "subnet-864707df"
}

variable "lambda_private_subnet_azs" {
  type        = list(string)
  description = "Availability zones for private subnets (must align with CIDRs list)."
  default     = ["us-west-1a", "us-west-1b"]
}

variable "lambda_private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for Lambda private subnets (must align with AZs list)."
  default     = ["172.31.128.0/20", "172.31.144.0/20"]
}

variable "redshift_security_group_id" {
  type        = string
  description = "Security group ID attached to the Redshift cluster."
  default     = "sg-b7e08ed3"
}

