variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment name (prod)"
}

variable "cluster_version" {
  type        = string
  default     = "1.31"
  description = "Kubernetes version for EKS"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EKS cluster and node groups will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for EKS node group and control plane endpoints"
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium", "t3a.medium", "t2.medium"]
  description = "Mixed EC2 instance types for Spot EKS worker nodes for high availability"
}

variable "desired_size" {
  type        = number
  default     = 3
  description = "Desired number of worker nodes for HA"
}

variable "min_size" {
  type        = number
  default     = 2
  description = "Minimum number of worker nodes for HA"
}

variable "max_size" {
  type        = number
  default     = 5
  description = "Maximum number of worker nodes for HA"
}

variable "disk_size" {
  type        = number
  default     = 30
  description = "EBS disk size in GB for worker nodes"
}
