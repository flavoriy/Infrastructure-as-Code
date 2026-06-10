variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to attach the security group"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "aws_ami_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
}

variable "aws_instance_type" {
  description = "The EC2 instance type"
  type        = string
  default     = "t2.small"
}

variable "key_name" {
  description = "The name of the SSH key pair"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID to launch the instance in"
  type        = string
}

variable "private_ip" {
  description = "The private IP address to assign to the instance"
  type        = string
}

variable "ingress_ports" {
  description = "List of ingress ports to allow in the security group"
  type        = list(number)
}

variable "private_ingress_ports" {
  description = "List of TCP ingress ports to allow only from private CIDR blocks"
  type        = list(number)
  default     = []
}

variable "private_ingress_udp_ports" {
  description = "List of UDP ingress ports to allow only from private CIDR blocks"
  type        = list(number)
  default     = []
}

variable "private_ingress_cidr_blocks" {
  description = "Private CIDR blocks allowed to reach private ingress ports"
  type        = list(string)
  default     = []
}

variable "volume_size" {
  description = "The size of the root EBS volume in GB"
  type        = number
  default     = 20
}
