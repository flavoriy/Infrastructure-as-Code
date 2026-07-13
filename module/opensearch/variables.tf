variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where OpenSearch will be deployed"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block allowed to communicate with OpenSearch"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for OpenSearch VPC endpoint placement (requires 2 subnets for Multi-AZ)"
  type        = list(string)
}

variable "engine_version" {
  description = "OpenSearch engine version"
  type        = string
  default     = "OpenSearch_2.11"
}

variable "instance_type" {
  description = "Instance type for OpenSearch data nodes"
  type        = string
  default     = "t3.medium.search"
}

variable "instance_count" {
  description = "Number of data nodes in the cluster (use 2 for Multi-AZ HA)"
  type        = number
  default     = 2
}

variable "volume_type" {
  description = "EBS volume type for data storage"
  type        = string
  default     = "gp3"
}

variable "volume_size" {
  description = "EBS volume size per node in GB"
  type        = number
  default     = 30
}

variable "create_service_linked_role" {
  description = "Whether to create the service-linked role for OpenSearch"
  type        = bool
  default     = false
}
