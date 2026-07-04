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
