variable "region" {
  type        = string
  description = "AWS region for bootstrap resources."
  default     = "us-west-1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for bootstrap resource names."
  default     = "mql"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all bootstrap resources."
  default     = {}
}

