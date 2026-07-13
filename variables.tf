variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "tikto"
}

variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dev_subnet_cidr" {
  description = "The CIDR block for the dev public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "prod_subnet_cidrs" {
  description = "The CIDR blocks for the prod public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
}

variable "dev_private_ips" {
  description = "Private IP addresses for dev subnet resources: k3s dev"
  type        = list(string)
  default     = ["10.0.1.12"]
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
}

variable "key_name" {
  description = "The name of the SSH key pair to use for the EC2 instance"
  type        = string
  default     = "devops-project"
}

# Dev K3s EC2 Variables
variable "instance_type_k3s_dev" {
  description = "The EC2 instance type for the dev k3s server"
  type        = string
  default     = "t3.small"
}

variable "ingress_ports_k3s_dev" {
  description = "List of public ingress ports for the dev single-node k3s server"
  type        = list(number)
  default     = [30080, 30443]
}

variable "admin_ports_k3s_dev" {
  description = "List of admin ports to restrict for the dev single-node k3s server"
  type        = list(number)
  default     = [22, 6443]
}

variable "volume_size_k3s_dev" {
  description = "The size of the root EBS volume for the dev k3s server (in GB)"
  type        = number
  default     = 20
}

# Prod EKS Cluster Variables (HA & Spot Optimization)
variable "eks_cluster_version" {
  description = "Kubernetes version for Prod EKS cluster"
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_types" {
  description = "Mixed EC2 instance types for Prod EKS Spot node group"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium", "t2.medium"]
}

variable "eks_desired_size" {
  description = "Desired number of worker nodes for Prod HA"
  type        = number
  default     = 3
}

variable "eks_min_size" {
  description = "Minimum number of worker nodes for Prod HA"
  type        = number
  default     = 2
}

variable "eks_max_size" {
  description = "Maximum number of worker nodes for Prod HA"
  type        = number
  default     = 5
}

# Dedicated Argo CD Management Server Variables
variable "argo_server_private_ip" {
  description = "Private IP for the dedicated Argo CD management server"
  type        = string
  default     = "10.0.1.10"
}

variable "instance_type_argo_server" {
  description = "The EC2 instance type for the dedicated Argo CD management server"
  type        = string
  default     = "t3.small"
}

variable "ingress_ports_argo_server" {
  description = "List of public ingress ports for the Argo CD management server"
  type        = list(number)
  default     = [80, 443, 30080, 30443]
}

variable "admin_ports_argo_server" {
  description = "List of admin ports to restrict for the Argo CD management server"
  type        = list(number)
  default     = [22, 6443]
}

variable "volume_size_argo_server" {
  description = "The size of the root EBS volume for the Argo CD management server (in GB)"
  type        = number
  default     = 20
}

# OpenSearch Service Variables
variable "opensearch_engine_version" {
  description = "OpenSearch engine version"
  type        = string
  default     = "OpenSearch_2.11"
}

variable "opensearch_instance_type" {
  description = "Instance type for Prod OpenSearch cluster data nodes"
  type        = string
  default     = "t3.medium.search"
}

variable "opensearch_instance_count" {
  description = "Number of data nodes in Prod OpenSearch cluster (2 for Multi-AZ)"
  type        = number
  default     = 2
}

variable "opensearch_volume_size" {
  description = "EBS volume size in GB per OpenSearch node"
  type        = number
  default     = 30
}

variable "opensearch_volume_type" {
  description = "EBS volume type for OpenSearch cluster"
  type        = string
  default     = "gp3"
}

# AWS Secrets Manager Variables
variable "secret_key_dev" {
  description = "AWS Secrets Manager key name for development environment"
  type        = string
  default     = "tikto/dev"
}

variable "secret_key_prod" {
  description = "AWS Secrets Manager key name for production environment"
  type        = string
  default     = "tikto/prod"
}

# Development Secrets
variable "dev_database_url" {
  description = "Database URL for development"
  type        = string
  sensitive   = true
  default     = null
}

variable "dev_calendar_database_url" {
  description = "Calendar Database URL for development"
  type        = string
  sensitive   = true
  default     = null
}

variable "dev_profile_database_url" {
  description = "Profile Database URL for development"
  type        = string
  sensitive   = true
  default     = null
}

variable "dev_tasks_database_url" {
  description = "Tasks Database URL for development"
  type        = string
  sensitive   = true
  default     = null
}

variable "dev_tikto_calendar_api_url" {
  description = "TikTo Calendar API URL for development"
  type        = string
  default     = null
}

variable "dev_tikto_dashboard_api_url" {
  description = "TikTo Dashboard API URL for development"
  type        = string
  default     = null
}

variable "dev_tikto_profile_api_url" {
  description = "TikTo Profile API URL for development"
  type        = string
  default     = null
}

variable "dev_tikto_tasks_api_url" {
  description = "TikTo Tasks API URL for development"
  type        = string
  default     = null
}

variable "dev_next_public_app_url" {
  description = "Next Public App URL for development"
  type        = string
  default     = null
}

variable "dev_tikto_internal_api_key" {
  description = "TikTo Internal API Key for development"
  type        = string
  sensitive   = true
  default     = null
}

variable "dev_next_public_supabase_publishable_key" {
  description = "Supabase Publishable Key for development"
  type        = string
  sensitive   = true
  default     = null
}

variable "dev_sonar_token" {
  description = "Sonar Token for development"
  type        = string
  sensitive   = true
  default     = null
}

variable "dev_gitops_token" {
  description = "GitOps Token for development"
  type        = string
  sensitive   = true
  default     = null
}

variable "dev_gitops_username" {
  description = "GitOps Username for development"
  type        = string
  default     = null
}

variable "dev_token_encryption_key" {
  description = "Token Encryption Key for development"
  type        = string
  sensitive   = true
  default     = null
}

# Production Secrets
variable "prod_database_url" {
  description = "Database URL for production"
  type        = string
  sensitive   = true
  default     = null
}

variable "prod_calendar_database_url" {
  description = "Calendar Database URL for production"
  type        = string
  sensitive   = true
  default     = null
}

variable "prod_profile_database_url" {
  description = "Profile Database URL for production"
  type        = string
  sensitive   = true
  default     = null
}

variable "prod_tasks_database_url" {
  description = "Tasks Database URL for production"
  type        = string
  sensitive   = true
  default     = null
}

variable "prod_tikto_calendar_api_url" {
  description = "TikTo Calendar API URL for production"
  type        = string
  default     = null
}

variable "prod_tikto_dashboard_api_url" {
  description = "TikTo Dashboard API URL for production"
  type        = string
  default     = null
}

variable "prod_tikto_profile_api_url" {
  description = "TikTo Profile API URL for production"
  type        = string
  default     = null
}

variable "prod_tikto_tasks_api_url" {
  description = "TikTo Tasks API URL for production"
  type        = string
  default     = null
}

variable "prod_next_public_app_url" {
  description = "Next Public App URL for production"
  type        = string
  default     = null
}

variable "prod_tikto_internal_api_key" {
  description = "TikTo Internal API Key for production"
  type        = string
  sensitive   = true
  default     = null
}

variable "prod_next_public_supabase_publishable_key" {
  description = "Supabase Publishable Key for production"
  type        = string
  sensitive   = true
  default     = null
}

variable "prod_sonar_token" {
  description = "Sonar Token for production"
  type        = string
  sensitive   = true
  default     = null
}

variable "prod_gitops_token" {
  description = "GitOps Token for production"
  type        = string
  sensitive   = true
  default     = null
}

variable "prod_gitops_username" {
  description = "GitOps Username for production"
  type        = string
  default     = null
}

variable "prod_token_encryption_key" {
  description = "Token Encryption Key for production"
  type        = string
  sensitive   = true
  default     = null
}


