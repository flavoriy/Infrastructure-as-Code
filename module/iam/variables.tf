variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role"
  type        = string
}

variable "assume_role_service" {
  description = "The AWS service that can assume this role (e.g. ec2.amazonaws.com)"
  type        = string
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach to this role"
  type        = list(string)
  default     = []
}

variable "create_instance_profile" {
  description = "Whether to create an EC2 instance profile for this role"
  type        = bool
  default     = false
}
