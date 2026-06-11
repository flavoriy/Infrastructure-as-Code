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

variable "subnet_cidr" {
  description = "The CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_ip" {
  description = "IP addresses for the subnets"
  type        = list(string)
  default     = ["10.0.1.10", "10.0.1.11", "10.0.1.12", "10.0.1.13", "10.0.1.14"]
}

variable "aim_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "ingress_ports_jenkins_server" {
  description = "List of ingress ports for the Jenkins server"
  type        = list(number)
  default     = [22, 8080]
}

variable "volume_size_jenkins_server" {
  description = "The size of the root EBS volume for the Jenkins server (in GB)"
  type        = number
  default     = 20
}

variable "ingress_ports_jenkins_agent" {
  description = "List of ingress ports for the Jenkins agent"
  type        = list(number)
  default     = [22]
}

variable "volume_size_jenkins_agent" {
  description = "The size of the root EBS volume for the Jenkins agent (in GB)"
  type        = number
  default     = 10
}

variable "ingress_ports_k3s_dev" {
  description = "List of public ingress ports for the dev single-node k3s server"
  type        = list(number)
  default     = [22, 6443, 30080, 30443]
}

variable "volume_size_k3s_dev" {
  description = "The size of the root EBS volume for the dev k3s server (in GB)"
  type        = number
  default     = 15
}

variable "ingress_ports_k3s_prod" {
  description = "List of public ingress ports for each prod k3s server"
  type        = list(number)
  default     = [22, 6443, 30080, 30443]
}

variable "private_ingress_ports_k3s_prod" {
  description = "List of private ingress ports for k3s HA server-to-server traffic"
  type        = list(number)
  default     = [2379, 2380, 10250]
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
  default     = "jenkins-share-lib"
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

variable "instance_type_jenkins_server" {
  description = "The EC2 instance type for the Jenkins server"
  type        = string
  default     = "t2.small"
}

variable "instance_type_jenkins_agent" {
  description = "The EC2 instance type for the Jenkins agent"
  type        = string
  default     = "t2.micro"
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
