variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "ap-southeast-1"
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

variable "prod_private_ips" {
  description = "Private IP addresses for prod k3s server resources"
  type        = list(string)
  default     = ["10.0.2.10", "10.0.3.10", "10.0.4.10"]

  validation {
    condition     = length(var.prod_private_ips) >= 3
    error_message = "prod_private_ips must contain at least 3 IP addresses for the prod k3s server quorum."
  }
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}



variable "ingress_ports_k3s_dev" {
  description = "List of public ingress ports for the dev single-node k3s server (e.g. NodePorts)"
  type        = list(number)
  default     = [30080, 30443]
}

variable "admin_ports_k3s_dev" {
  description = "List of admin ports to restrict for the dev single-node k3s server (e.g. SSH, API)"
  type        = list(number)
  default     = [22, 6443]
}

variable "volume_size_k3s_dev" {
  description = "The size of the root EBS volume for the dev k3s server (in GB)"
  type        = number
  default     = 15
}

variable "ingress_ports_k3s_prod" {
  description = "List of public ingress ports for each prod k3s server (e.g. NodePorts)"
  type        = list(number)
  default     = [30080, 30443]
}

variable "admin_ports_k3s_prod" {
  description = "List of admin ports to restrict for each prod k3s server (e.g. SSH, API)"
  type        = list(number)
  default     = [22, 6443]
}

variable "private_ingress_ports_k3s_prod" {
  description = "List of private ingress ports for k3s HA server-to-server traffic"
  type        = list(number)
  default     = [6443, 2379, 2380, 10250]
}

variable "private_ingress_udp_ports_k3s_prod" {
  description = "List of private UDP ingress ports for k3s pod networking"
  type        = list(number)
  default     = [8472]
}

variable "volume_size_k3s_prod" {
  description = "The size of the root EBS volume for each prod k3s server (in GB)"
  type        = number
  default     = 15
}

variable "key_name" {
  description = "The name of the SSH key pair to use for the EC2 instance"
  type        = string
  default     = "devops-project"
}



variable "instance_type_k3s_dev" {
  description = "The EC2 instance type for the dev k3s server"
  type        = string
  default     = "t2.small"
}

variable "instance_type_k3s_prod" {
  description = "The EC2 instance type for each prod k3s server"
  type        = string
  default     = "t3a.medium"
}
