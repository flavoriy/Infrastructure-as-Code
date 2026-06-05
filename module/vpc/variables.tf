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

variable "subnet_cidr" {
    description = "CIDR block for the public subnet"
    type        = string
    default     = "10.0.1.0/24"
}
