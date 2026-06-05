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
  default     = "m7i.large"
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

variable "volume_size" {
  description = "The size of the root EBS volume in GB"
  type        = number
  default     = 20
}

variable "instance_state" {
  description = "The desired state of the EC2 instance (running or stopped)"
  type        = string
  default     = "running"
}
