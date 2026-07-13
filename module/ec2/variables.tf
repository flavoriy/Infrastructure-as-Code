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

variable "cpu_credits" {
  description = "CPU credit option for burstable EC2 instances. Use standard to avoid extra unlimited burst charges."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "unlimited"], var.cpu_credits)
    error_message = "cpu_credits must be either standard or unlimited."
  }
}

variable "enable_detailed_monitoring" {
  description = "Enable paid EC2 detailed monitoring. Keep false for cost-optimized lab usage."
  type        = bool
  default     = false
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

variable "ingress_rules" {
  description = "List of ingress rules specifying port, protocol, cidr_blocks and optional description"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = optional(string)
  }))
  default = []
}

variable "volume_size" {
  description = "The size of the root EBS volume in GB"
  type        = number
  default     = 20
}

variable "associate_eip" {
  description = "Whether to allocate and associate an Elastic IP with the instance"
  type        = bool
  default     = true
}

variable "user_data" {
  description = "User data script to execute on initial instance boot"
  type        = string
  default     = null
}

