variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "secret_arn" {
  description = "ARN of the Secrets Manager secret"
  type        = string
}

variable "opensearch_domain_arn" {
  description = "ARN of the OpenSearch domain"
  type        = string
}

variable "eks_node_role_name" {
  description = "Name of the EKS node group IAM role to attach policies to"
  type        = string
}
