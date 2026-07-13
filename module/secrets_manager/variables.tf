variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, prod)"
}

variable "secret_name" {
  type        = string
  description = "AWS Secrets Manager secret name (e.g. tikto/dev)"
}

variable "description" {
  type        = string
  default     = "Secrets Manager key for application secrets"
  description = "Description for the secret"
}

variable "secret_values" {
  type        = map(string)
  description = "Key-value pair map of secrets to store as JSON"
  default     = {}
}
