variable "project_name" {
  description = "Project name"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dev_subnet_cidr" {
  description = "CIDR block for the dev public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "prod_subnet_cidrs" {
  description = "The CIDR blocks for the prod public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]
}
